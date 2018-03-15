
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
	_process_id := grape.process_id_by_name(_process_name);

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
	SELECT process_id FROM grape.process WHERE process_name=_process_name::TEXT;
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

/**
 * Returns information about a process's running and future scheduled tasks
 * Provide a process_name
 */
CREATE OR REPLACE FUNCTION grape.process_running_info (JSON) RETURNS JSON AS $$
DECLARE
	_ret JSON;
	_process_name TEXT;
	_process_id INTEGER;
	_running JSON;
	_new JSON;
BEGIN
	_process_name := ($1->>'process_name')::TEXT;
	_process_id := grape.process_id_by_name(_process_name);

	IF _process_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	SELECT JSON_AGG(a) INTO _running FROM (SELECT schedule_id, time_started, pid, param, grape.username(user_id), progress_completed, progress_total FROM grape.schedule WHERE process_id=_process_id::INTEGER AND status='Running') a;
	SELECT JSON_AGG(a) INTO _new FROM (SELECT schedule_id, time_sched, param, grape.username(user_id) FROM grape.schedule WHERE process_id=_process_id::INTEGER AND status='NewTask') a;

	_ret := json_build_object('running', _running, 'new', _new);

	RETURN grape.api_success(_ret);
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
	ELSIF $1 ? 'process_name' THEN
		_process_id := (SELECT process_id FROM grape.process WHERE process_name=$1->>'process_name');
	ELSIF $1 ? 'process_id' THEN
		_process_id := ($1->>'process_id')::INTEGER;
	END IF;
	
	IF _process_id IS NULL THEN
		RETURN grape.api_error_invalid_input(json_build_object('reason', 'Process could not be found'));
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


