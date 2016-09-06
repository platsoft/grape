
/**
 * Add a new entry to process schedule table
 * 
 * Provide a process_id and params
 */
CREATE OR REPLACE FUNCTION grape.start_process (_process_id INTEGER, _param JSON) RETURNS INTEGER AS $$
DECLARE
	_schedule_id INTEGER;
BEGIN
	INSERT INTO grape.schedule (process_id, time_sched, param, user_id) 
		VALUES (_process_id, CURRENT_TIMESTAMP, _param, current_user_id()) 
		RETURNING schedule_id INTO _schedule_id;

	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;

/**
 * Add a new entry to process schedule table
 * 
 * Provide a process_id and params
 */
CREATE OR REPLACE FUNCTION grape.start_process (_process_name TEXT, _param JSON) RETURNS INTEGER AS $$
DECLARE
	_process_id INTEGER;
	_schedule_id INTEGER;
BEGIN
	
	SELECT process_id INTO _process_id FROM grape.process WHERE pg_function=_process_name::TEXT;

	IF _process_id IS NULL THEN
		RETURN -1;
	END IF;

	_schedule_id := grape.start_process(_process_id, _param);

	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;


/**
 * Wrapper to start function
 */
CREATE OR REPLACE FUNCTION grape.start_process (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_process_name TEXT;
	_param JSON;
	_schedule_id INTEGER;
BEGIN
	_param := $1->'param';

	IF json_extract_path($1, 'process_id') IS NOT NULL THEN
		_process_id := ($1->>'process_id')::INTEGER;
		_schedule_id := grape.start_process(_process_id, _param);
	ELSIF json_extract_path($1, 'process_name') IS NOT NULL THEN
		_process_name := ($1->>'process_name')::TEXT;
		_schedule_id := grape.start_process(_process_name, _param);
	ELSE
		RETURN grape.api_error_invalid_input();
	END IF;

	RETURN grape.api_success('schedule_id', _schedule_id);
END; $$ LANGUAGE plpgsql;

/**
 * Returns list of processes and totals
 */
CREATE OR REPLACE FUNCTION grape.list_processes (JSON) RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	SELECT json_agg(r) INTO _ret FROM (
		SELECT 
			ap.process_id, 
			pg_function, 
			description, 
			param,
			(SELECT json_agg(auto_scheduler) FROM grape.auto_scheduler WHERE process_id=ap.process_id) AS auto_scheduler,
			count_new.count AS "new", 
			count_completed.count AS "completed", 
			count_error.count AS "error", 
			count_running.count AS "running"
		FROM grape.process AS ap, 
			LATERAL (SELECT COUNT(*) FROM grape.schedule WHERE process_id=ap.process_id AND status='NewTask') AS count_new,
			LATERAL (SELECT COUNT(*) FROM grape.schedule WHERE process_id=ap.process_id AND status='Completed') AS count_completed,
			LATERAL (SELECT COUNT(*) FROM grape.schedule WHERE process_id=ap.process_id AND status='Error') AS count_error,
			LATERAL (SELECT COUNT(*) FROM grape.schedule WHERE process_id=ap.process_id AND status='Running') AS count_running
		) r;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


/**
 * Returns schedule information.
 * Provide a schedule_id
 */
CREATE OR REPLACE FUNCTION grape.schedule_info (JSON) RETURNS JSON AS $$
DECLARE
	_ret JSON;
	_schedule_id INTEGER;
BEGIN
	_schedule_id := ($1->>'schedule_id')::INTEGER;

	SELECT to_json(g) 
		INTO _ret 
		FROM grape.schedule g
		WHERE schedule_id=_schedule_id::INTEGER;

	RETURN grape.api_success('schedule', _ret);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.update_schedule_progress(_schedule_id INTEGER, _completed INTEGER, _total INTEGER) RETURNS VOID AS $$
DECLARE
BEGIN
	IF _completed > -1 AND _total > -1 THEN
		UPDATE grape.schedule SET progress_total=_total, progress_completed=_completed WHERE schedule_id=_schedule_id::INTEGER;
	ELSIF _completed > -1 THEN
		UPDATE grape.schedule SET progress_completed=_completed WHERE schedule_id=_schedule_id::INTEGER;
	ELSIF _total > -1 THEN
		UPDATE grape.schedule SET progress_total=_total WHERE schedule_id=_schedule_id::INTEGER;
	END IF;

	RETURN;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (_process_id INTEGER, _scheduled_interval INTERVAL, _dow TEXT, _dom TEXT, _time TIME, _run_as_user_id INTEGER DEFAULT NULL) RETURNS INTEGER AS $$
DECLARE
	
BEGIN
	IF _run_as_user_id IS NULL THEN
		_run_as_user_id := current_user_id();
	END IF;

	DELETE FROM grape.auto_scheduler WHERE process_id=_process_id::INTEGER;
	INSERT INTO grape.auto_scheduler (process_id, scheduled_interval, dow, days_of_month, day_time, run_as_user_id)
		VALUES (_process_id, _scheduled_interval, _dow, _dom, _time, _run_as_user_id);

	PERFORM grape.autoschedule_next_process(_process_id);

	RETURN _process_id;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_scheduled_interval INTERVAL;
	_dow TEXT;
	_dom TEXT;
	_time TIME;
	_run_as_user_id INTEGER;
BEGIN
	IF json_extract_path($1, 'process_id') IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	_process_id := ($1->>'process_id');

	IF json_extract_path($1, 'scheduled_interval') IS NOT NULL THEN
		_scheduled_interval := ($1->>'scheduled_interval')::INTERVAL;
	END IF;
	IF json_extract_path($1, 'dow') IS NOT NULL THEN
		_dow := $1->>'dow';
		IF _dow !~* '^([01]){7}$' THEN
			RETURN grape.api_result_error('Invalid input - dow should be a 7-character string containing ones and zeros', -2);
		END IF;
	END IF;
	IF json_extract_path($1, 'days_of_month') IS NOT NULL THEN
		_dom := $1->>'dom';
	END IF;
	IF json_extract_path($1, 'time') IS NOT NULL THEN
		_time := ($1->>'time')::TIME;
	END IF;

	PERFORM grape.save_process_auto_scheduler(_process_id, _scheduled_interval, _dow, _dom, _time);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.autoschedule_for_date(_process_id INTEGER, _date DATE, _interval INTERVAL, _time TIME, _user_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_schedule_id INTEGER;
	_start TIMESTAMP;
BEGIN
	DELETE FROM grape.schedule WHERE process_id=_process_id::INTEGER AND status='NewTask' AND time_sched::DATE=_date::DATE;

	IF _interval IS NOT NULL THEN
		_start := _date::TIMESTAMP;
		WHILE _start::DATE = _date LOOP

			IF _start >= NOW() THEN -- only schedule for after now
				INSERT INTO grape.schedule (process_id, time_sched, param, user_id) 
					VALUES (_process_id, _start, '{}'::JSON, _user_id) 
					RETURNING schedule_id INTO _schedule_id;
			END IF;

			_start := _start + _interval;
		END LOOP;
	ELSIF _time IS NOT NULL THEN

		IF  (_date + _time)::TIMESTAMP < NOW() THEN -- not scheduling for before now
			RETURN -1;
		END IF;

		INSERT INTO grape.schedule (process_id, time_sched, param, user_id) 
			VALUES (_process_id, (_date + _time)::TIMESTAMP, '{}'::JSON, _user_id) 
			RETURNING schedule_id INTO _schedule_id;
	END IF;

	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.autoschedule_next_process(_process_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_schedule_id INTEGER;
	_rec RECORD;
	_days_of_month_s TEXT[];
	_days_of_month INTEGER[];
	_dow VARCHAR(7);
	_s TEXT;

	_d DATE;

	_every_dom BOOLEAN;
	_every_dow BOOLEAN;
BEGIN
	SELECT * INTO _rec FROM grape.auto_scheduler WHERE process_id=_process_id::INTEGER;
	IF NOT FOUND THEN
		RETURN -1;
	END IF;
	
	DELETE FROM grape.schedule WHERE process_id=_process_id::INTEGER AND status='NewTask' AND time_sched > NOW();

	IF _rec.days_of_month = '*' OR _rec.days_of_month = '' OR _rec.days_of_month = NULL THEN -- every day of the month
		_every_dom := TRUE;
	ELSE
		_every_dom := FALSE;
		_days_of_month := '{}'::INTEGER[];
		_days_of_month_s := string_to_array(_rec.days_of_month, ',');
		FOREACH _s IN ARRAY _days_of_month_s LOOP
			BEGIN
				_days_of_month := array_append(_days_of_month, _s::INTEGER);
			EXCEPTION WHEN OTHERS THEN
			END;
		END LOOP;
	END IF;

	IF _rec.dow = '1111111' OR _rec.dow = '0000000' THEN
		_every_dow := TRUE;
	ELSE
		_every_dow := FALSE;
	END IF;

	_d := CURRENT_DATE;
	WHILE _d < CURRENT_DATE + '1 week'::INTERVAL LOOP
		IF _every_dom = TRUE AND _every_dow = TRUE THEN
			_schedule_id := grape.autoschedule_for_date(_process_id, _d, _rec.scheduled_interval, _rec.day_time, _rec.run_as_user_id);
		ELSIF _every_dom = TRUE AND _every_dow = FALSE THEN

			IF SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _d)::INTEGER, 1) = '1' THEN
				_schedule_id := grape.autoschedule_for_date(_process_id, _d, _rec.scheduled_interval, _rec.day_time, _rec.run_as_user_id);
			END IF;

		ELSIF _every_dom = FALSE AND _every_dow = TRUE THEN

			IF ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _d)::INTEGER) IS NOT NULL THEN
				_schedule_id := grape.autoschedule_for_date(_process_id, _d, _rec.scheduled_interval, _rec.day_time, _rec.run_as_user_id);
			END IF;

		ELSIF _every_dom = FALSE AND _every_dow = FALSE THEN

			IF ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _d)) IS NOT NULL
				AND SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _d)::INTEGER, 1) = '1' THEN
					_schedule_id := grape.autoschedule_for_date(_process_id, _d, _rec.scheduled_interval, _rec.day_time, _rec.run_as_user_id);
			END IF;
		END IF;
		_d := _d + INTERVAL '1 day';
	END LOOP;
	RETURN 1;
END; $$ LANGUAGE plpgsql;


