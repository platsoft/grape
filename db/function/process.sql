
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

CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (_process_id INTEGER, _scheduled_interval INTERVAL, _dow TEXT, _dom TEXT, _time TIME) RETURNS INTEGER AS $$
DECLARE
	
BEGIN
	DELETE FROM grape.auto_scheduler WHERE process_id=_process_id::INTEGER;
	INSERT INTO grape.auto_scheduler (process_id, scheduled_interval, dow, days_of_month, day_time)
		VALUES (_process_id, _scheduled_interval, _dow, _dom, _time);

	RETURN _process_id;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_scheduled_interval INTERVAL;
	_dow TEXT;
	_dom TEXT;
	_time TIME;
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



