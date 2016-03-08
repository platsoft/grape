
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
	SELECT to_json(array_agg(r)) INTO _ret FROM (
		SELECT process_id, pg_function, description, param, 
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




