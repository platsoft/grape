
/**
 * Add a new entry to process schedule table
 * 
 * Provide a process_id and params
 */
CREATE OR REPLACE FUNCTION grape.start_process (_process_id INTEGER, _param JSON, _time_sched TIMESTAMPTZ DEFAULT NOW()) RETURNS INTEGER AS $$
DECLARE
	_schedule_id INTEGER;
	_filter_processes BOOLEAN;
BEGIN
	_filter_processes := (grape.get_value('filter_processes', 'false'))::BOOLEAN;

	IF _filter_processes = TRUE AND grape.check_process_execute_permission(_process_id) = FALSE THEN
		RETURN -2;
	END IF;

	INSERT INTO grape.schedule (process_id, time_sched, param, user_id) 
		VALUES (_process_id, _time_sched, _param, current_user_id()) 
		RETURNING schedule_id INTO _schedule_id;

	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;

/**
 * Add a new entry to process schedule table
 * 
 * Provide a process_id and params
 */
CREATE OR REPLACE FUNCTION grape.start_process (_process_name TEXT, _param JSON, _time_sched TIMESTAMPTZ DEFAULT NOW()) RETURNS INTEGER AS $$
DECLARE
	_process_id INTEGER;
	_schedule_id INTEGER;
BEGIN
	
	SELECT process_id INTO _process_id FROM grape.process WHERE pg_function=_process_name::TEXT;

	IF _process_id IS NULL THEN
		RETURN -1;
	END IF;

	_schedule_id := grape.start_process(_process_id, _param, _time_sched);

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
	_time_sched TIMESTAMPTZ;

BEGIN
	_param := $1->'param';

	_time_sched := NOW();

	IF json_extract_path($1, 'time_sched') IS NOT NULL THEN
		_time_sched := ($1->>'time_sched')::TIMESTAMPTZ;
	END IF;

	IF json_extract_path($1, 'process_id') IS NOT NULL THEN
		_process_id := ($1->>'process_id')::INTEGER;
		_schedule_id := grape.start_process(_process_id, _param, _time_sched);
	ELSIF json_extract_path($1, 'process_name') IS NOT NULL THEN
		_process_name := ($1->>'process_name')::TEXT;
		_schedule_id := grape.start_process(_process_name, _param, _time_sched);
	ELSE
		RETURN grape.api_error_invalid_input();
	END IF;

	IF _schedule_id = -2 THEN
		RETURN grape.api_error('You have insufficient permissions to start this process', -2);
	ELSIF _schedule_id < 0 THEN
		RETURN grape.api_error('An unknown error occured', _schedule_id);
	ELSE
		RETURN grape.api_success('schedule_id', _schedule_id);
	END IF;
END; $$ LANGUAGE plpgsql;

/**
 * Returns process id of name
 */
CREATE OR REPLACE FUNCTION grape.process_id_by_name(_process_name TEXT) RETURNS INTEGER AS $$
	SELECT process_id FROM grape.process WHERE pg_function=_process_name::TEXT;
$$ LANGUAGE sql;


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

/**
 *
 * days_of_month '*' or something like '1,15'
 * dow ('0111110')
 * process_id or process_name
 * scheduled_interval or day_time
 * auto_scheduler_id to update one of it
 * active BOOLEAN
 * params JSON
 */
CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_scheduled_interval INTERVAL;
	_dow TEXT;
	_dom TEXT;
	_time TIME;
	_run_as_user_id INTEGER;
	_auto_scheduler_id INTEGER;
	_run_with_params JSON;
	_active BOOLEAN;
BEGIN
	IF json_extract_path($1, 'auto_scheduler_id') IS NOT NULL THEN
		_auto_scheduler_id := ($1->>'auto_scheduler_id')::INTEGER;

		SELECT process_id, scheduled_interval, dow, days_of_month, day_time, run_with_params, run_as_user_id, active
		INTO _process_id, _scheduled_interval, _dow, _dom, _time, _run_with_params, _run_as_user_id, _active
			FROM grape.auto_scheduler
			WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	ELSE
		-- defaults
		_run_with_params := '{}';
		_run_as_user_id := current_user_id();
		_active := TRUE;
	END IF;


	IF json_extract_path($1, 'process_id') IS NOT NULL THEN
		_process_id := ($1->>'process_id')::INTEGER;
	END IF;
	IF json_extract_path($1, 'process_name') IS NOT NULL THEN
		_process_id := (SELECT process_id FROM grape.process WHERE pg_function=$1->>'process_name');
	END IF;

	IF _process_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

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
		_dom := $1->>'days_of_month';
	END IF;

	IF json_extract_path($1, 'day_time') IS NOT NULL THEN
		_time := ($1->>'day_time')::TIME;
	END IF;

	IF json_extract_path($1, 'params') IS NOT NULL THEN
		_run_with_params := $1->'params';
	END IF;

	IF json_extract_path($1, 'user_id') IS NOT NULL THEN
		_run_as_user_id := ($1->>'user_id')::INTEGER;
	END IF;

	IF json_extract_path($1, 'active') IS NOT NULL THEN
		_active := ($1->>'active')::BOOLEAN;
	END IF;


	IF _time IS NOT NULL AND _scheduled_interval IS NOT NULL THEN
		RETURN grape.api_result_error('Invalid input - cannot provide interval and time', -3);
	END IF;

	IF _scheduled_interval IS NOT NULL AND _scheduled_interval >= '1 day'::INTERVAL THEN
		RETURN grape.api_result_error('Invalid input - interval cannot be longer than a day', -3);
	END IF;

	IF _scheduled_interval IS NULL AND _time IS NULL THEN
		RETURN grape.api_result_error('Invalid input - need to provide either day_time or scheduled_interval', -3);
	END IF;

	IF _auto_scheduler_id IS NOT NULL THEN
		DELETE FROM grape.schedule WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER AND status='NewTask';
		UPDATE grape.auto_scheduler SET
			scheduled_interval=_scheduled_interval,
			dow=_dow,
			days_of_month=_dom,
			day_time=_time,
			run_as_user_id=_run_as_user_id,
			run_with_params=_run_with_params,
			active=_active

			WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	ELSE
		INSERT INTO grape.auto_scheduler (process_id, scheduled_interval, dow, days_of_month, day_time, run_as_user_id, run_with_params, active) 
			VALUES (_process_id, _scheduled_interval, _dow, _dom, _time, _run_as_user_id, _run_with_params, _active)
			RETURNING auto_scheduler_id INTO _auto_scheduler_id;
	END IF;

	PERFORM grape.autoschedule_next(_auto_scheduler_id);

	RETURN grape.api_success('auto_scheduler_id', _auto_scheduler_id);
END; $$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.autoschedule_next(_auto_scheduler_id INTEGER, _now TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP) RETURNS INTEGER AS $$
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

	_last_run TIMESTAMP;
	_time_sched TIMESTAMP;
BEGIN
	SELECT * INTO _rec FROM grape.auto_scheduler WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	IF NOT FOUND THEN
		RETURN -1;
	END IF;
	
	IF _rec.days_of_month = '*' OR _rec.days_of_month = '' OR _rec.days_of_month IS NULL THEN -- every day of the month
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

	SELECT MAX(time_sched) INTO _last_run FROM grape.schedule WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	IF _last_run IS NULL THEN
		_last_run := _now::DATE - '1 day'::INTERVAL; 
	END IF;

	-- find the next day it can run on (it might be today)
	IF _rec.day_time IS NOT NULL THEN -- once a day at time
		_time_sched := ((_last_run::DATE) + '1 day'::INTERVAL) + _rec.day_time; -- initial value
	ELSIF _rec.scheduled_interval IS NOT NULL THEN 
		_time_sched := _last_run + _rec.scheduled_interval;
	END IF;

	IF _every_dom = TRUE AND _every_dow = TRUE THEN -- every day
		IF _rec.day_time IS NOT NULL THEN -- once a day at time
			_time_sched := ((_last_run + '1 day'::INTERVAL)::DATE + _rec.day_time)::TIMESTAMP;
		ELSIF _rec.scheduled_interval IS NOT NULL THEN -- interval
			_time_sched := _last_run::DATE;
			WHILE _time_sched <= _now LOOP
				_time_sched := _time_sched + _rec.scheduled_interval;
			END LOOP;
		END IF;
	ELSIF _every_dom = TRUE AND _every_dow = FALSE THEN -- some days of the week only

		WHILE 
			SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _time_sched)::INTEGER + 1, 1) = '0' 
			OR _time_sched <= _now 
		LOOP
			IF _rec.day_time IS NOT NULL THEN -- once a day at time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;
		END LOOP;

	ELSIF _every_dom = FALSE AND _every_dow = TRUE THEN -- some days of the month only

		WHILE 
			ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _time_sched)::INTEGER) IS NULL 
			OR _time_sched <= _now 
		LOOP
			IF _rec.day_time IS NOT NULL THEN -- once a day at time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;
		END LOOP;

	ELSIF _every_dom = FALSE AND _every_dow = FALSE THEN
		WHILE 
			ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _time_sched)::INTEGER) IS NULL 
			OR SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _time_sched)::INTEGER + 1, 1) = '0' 
			OR _time_sched <= _now 
		LOOP

			IF _rec.day_time IS NOT NULL THEN -- once a day at time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;

		END LOOP;
	END IF;

	INSERT INTO grape.schedule (process_id, time_sched, param, user_id, status, auto_scheduler_id)
		VALUES (_rec.process_id, _time_sched, _rec.run_with_params, _rec.run_as_user_id, 'NewTask', _auto_scheduler_id)
		RETURNING schedule_id INTO _schedule_id;


	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.schedule_done(_schedule_id INTEGER, _status TEXT) RETURNS VOID AS $$
DECLARE
	_auto_scheduler_id INTEGER;
BEGIN
	SELECT auto_scheduler_id INTO _auto_scheduler_id FROM grape.schedule WHERE schedule_id=_schedule_id::INTEGER;
	IF _auto_scheduler_id IS NOT NULL THEN
		IF EXISTS (SELECT 1 FROM grape.auto_scheduler WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER AND active=TRUE) THEN
			PERFORM grape.autoschedule_next(_auto_scheduler_id);
		END IF;
	END IF;
	RETURN;
END; $$ LANGUAGE plpgsql;

/**
 * Immediately run a process function
 */
CREATE OR REPLACE FUNCTION grape.run_process_function (_process_id INTEGER, _param JSON) RETURNS JSON AS $$
DECLARE
	_pg_function TEXT;
	_pg_function_schema TEXT;
	_sql TEXT;
	_ret JSON;
BEGIN
	SELECT pg_function, function_schema INTO _pg_function, _pg_function_schema FROM grape.process WHERE process_id=_process_id::INTEGER;

	IF _pg_function_schema IS NULL OR _pg_function_schema = '' THEN
		_pg_function_schema := 'grape';
	END IF;

	_sql := FORMAT('SELECT "%s"."%s"($1)', _pg_function_schema, _pg_function);
	
	EXECUTE _sql USING _param INTO _ret;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

/**
 * Immediately run a process function
 */
CREATE OR REPLACE FUNCTION grape.run_process_function (JSONB) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_param JSON;
BEGIN
	IF $1 ? 'pg_function' THEN
		_process_id := (SELECT process_id FROM grape.process WHERE pg_function=$1->>'pg_function');
	ELSIF $1 ? 'process_id' THEN
		_process_id := ($1->>'process_id')::INTEGER;
	END IF;
	
	IF _process_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	IF $1 ? 'param' THEN
		_param := ($1->'param')::JSON;
	ELSE
		_param := '{}';
	END IF;

	RETURN grape.api_success('output', grape.run_process_function(_process_id, _param));
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.select_auto_scheduler(JSONB) RETURNS JSON AS $$
	SELECT grape.api_success_if_not_null(
		'auto_scheduler', 
		(SELECT to_json(auto_scheduler) FROM grape.auto_scheduler WHERE auto_scheduler_id=($1->>'auto_scheduler_id')::INTEGER)
	);
$$ LANGUAGE sql;

/*
 * Return codes:
 * > 0 Schedule is not a DB function, this is the PID of process
 *  0: Schedule killed
 *  -1: Schedule not found
 *  -2: Schedule status is not "Running"
 *  -3: Access denied
 */
CREATE OR REPLACE FUNCTION grape.stop_running_schedule(_schedule_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_sched RECORD;
BEGIN
	-- TODO check that the current user has access to this process, if not return -3

	SELECT s.*, p.process_type INTO _sched FROM grape.schedule s JOIN grape.process p USING (process_id) WHERE schedule_id=_schedule_id::INTEGER;
	IF NOT FOUND THEN
		RETURN -1;
	END IF;

	IF _sched.status = 'NewTask' THEN
		DELETE FROM grape.schedule WHERE schedule_id=_schedule_id::INTEGER;
		RETURN 0;
	END IF;

	IF _sched.status != 'Running' THEN
		RETURN -2;
	END IF;

	IF _sched.process_type != 'DB' AND _sched.process_type != 'SQL' AND _sched.process_type IS NOT NULL THEN
		RETURN _sched.pid;
	END IF;

	PERFORM pg_cancel_backend(_sched.pid);
	
	RETURN 0;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.stop_running_schedule(JSONB) RETURNS JSONB AS $$
DECLARE
	_ret INTEGER;
	_schedule_id INTEGER;
BEGIN
	_schedule_id := ($1->>'schedule_id')::INTEGER;

	_ret := grape.stop_running_schedule(_schedule_id);

	IF _ret >= 0 THEN
		RETURN grape.api_success('pid', _ret);
	ELSIF _ret = -1 THEN
		RETURN grape.api_error_data_not_found();
	ELSIF _ret = -2 THEN
		RETURN grape.api_error_invalid_data_state();
	ELSIF _ret = -3 THEN
		RETURN grape.api_error_permission_denied();
	ELSE
		RETURN grape.api_error('Unknown error', _ret);
	END IF;

END; $$ LANGUAGE plpgsql;


