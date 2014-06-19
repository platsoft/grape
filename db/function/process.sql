
/**
 * process_id or process_name
 */
CREATE OR REPLACE FUNCTION grape.start_process (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_process_name TEXT;
	_param JSON;
	ret INTEGER;
BEGIN
	IF json_extract_path($1, 'process_id') IS NOT NULL THEN
		_process_id := ($1->>'process_id')::INTEGER;
	ELSE
		_process_name := ($1->>'process_name')::TEXT;
		SELECT process_id INTO _process_id FROM grape.process WHERE pg_function=_process_name::TEXT;
	END IF;

	_param := $1->'param';

	INSERT INTO grape.schedule (process_id, time_sched, param, user_id) VALUES (_process_id, CURRENT_TIMESTAMP, _param, current_user_id()) RETURNING schedule_id INTO ret;

	RETURN row_to_json(b) FROM (SELECT ret AS "schedule_id") b;
END; $$ LANGUAGE plpgsql;

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


