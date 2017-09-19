


CREATE OR REPLACE FUNCTION grape.save_process_definition(JSONB) RETURNS JSONB AS $$
DECLARE
	_description TEXT;
	_process_id INTEGER;
	_process_category TEXT;
	_process_type TEXT;
	_pg_function TEXT;
	_function_schema TEXT;
	_process_role JSONB;
	_role JSONB;
	_param JSON;
BEGIN
	_process_id := ($1->>'process_id')::INTEGER;
	_pg_function := ($1->>'pg_function');
	_description := ($1->>'description');
	_param := $1->'param';
	_process_type := ($1->>'process_type');
	_function_schema := ($1->>'function_schema');
	_process_category := ($1->>'process_category');
	
	_process_role := ($1->'process_role');
	
	-- TODO validation, make sure process_type is one of DB, EXEC or NODE

	IF _process_id IS NULL THEN
		INSERT INTO grape.process (
			pg_function,
			description,
			param,
			process_type,
			function_schema,
			process_category
		) VALUES (
			_pg_function,
			_description,
			_param,
			_process_type,
			_function_schema,
			_process_category
		);
	ELSE
		UPDATE grape.process SET
			pg_function=_pg_function,
			description=_description,
			param=_param,
			process_type=_process_type,
			function_schema=_function_schema,
			process_category=_process_category
		WHERE process_id=_process_id::INTEGER;
	END IF;

	FOR _role IN SELECT * FROM jsonb_array_elements(_process_role) LOOP
		PERFORM grape.process_role_update(
			_process_id, 
			_role->>'role_name', 
			(_role->>'can_view')::BOOLEAN, 
			(_role->>'can_execute')::BOOLEAN,
			(_role->>'can_edit')::BOOLEAN
		);
	END LOOP;

	RETURN grape.api_success('process_id', _process_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.upsert_process(
	_pg_function TEXT,
	_description TEXT,
	_param JSON,
	_process_type TEXT,
	_function_schema TEXT,
	_process_category TEXT) RETURNS VOID AS $$

	INSERT INTO grape.process (
		pg_function,
		description,
		param,
		process_type,
		function_schema,
		process_category
	)
	VALUES (
		_pg_function,
		_description,
		_param,
		_process_type,
		_function_schema,
		_process_category
	)
	ON CONFLICT (pg_function, function_schema) --if processing_function name is the same updatre all the other values 
	DO UPDATE SET 
		pg_function=EXCLUDED.pg_function,
		description=EXCLUDED.description,
		param=EXCLUDED.param,
		process_type=EXCLUDED.process_type,
		function_schema=EXCLUDED.function_schema,
		process_category=EXCLUDED.process_category;

$$ LANGUAGE sql;

/**
 * Returns list of processes and totals
 * If the grape setting filter_processes is true
 */
CREATE OR REPLACE FUNCTION grape.list_processes (JSON) RETURNS JSON AS $$
DECLARE
	_ret JSONB;
	_filter_processes BOOLEAN;
	_rec RECORD;
BEGIN
	_filter_processes := (grape.get_value('filter_processes', 'false'))::BOOLEAN;

	_ret := '[]'::JSONB;

	FOR _rec IN SELECT 
			ap.process_id, 
			pg_function, 
			description, 
			ap.process_category,
			ap.param,
			(SELECT json_agg(a.s) FROM 
				(SELECT (to_jsonb(b) || jsonb_build_object('run_as_user', grape.username(run_as_user_id))) s FROM 
					grape.auto_scheduler b 
					WHERE process_id=ap.process_id) a) AS auto_scheduler,

			(SELECT json_agg(process_role) FROM grape.process_role WHERE process_id=ap.process_id) AS process_role,
			sched.schedule_id,
			sched.time_sched,
			sched.time_started,
			sched.time_ended,
			sched.pid,
			sched.param AS sched_param,
			grape.username(sched.user_id) AS sched_username,
			sched.logfile,
			sched.status,
			sched.progress_completed,
			sched.progress_total,
			sched.auto_scheduler_id

		FROM grape.process AS ap
			LEFT JOIN LATERAL (SELECT * FROM grape.schedule WHERE process_id=ap.process_id ORDER BY time_sched DESC LIMIT 1) AS sched USING (process_id)
			ORDER BY ap.process_id
	LOOP
		IF _filter_processes = FALSE 
			OR (_filter_processes = TRUE AND grape.check_process_view_permission(_rec.process_id) = TRUE) THEN
				_ret := _ret || to_jsonb(_rec);
		END IF;
	END LOOP;

	RETURN _ret::JSON;
END; $$ LANGUAGE plpgsql;

/**
 * Returns a list of process categories
 * {"status":"OK","categories":[null, "Internal"]}
 */
CREATE OR REPLACE FUNCTION grape.list_process_categories(JSON) RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	SELECT JSON_AGG(DISTINCT process_category) INTO _ret FROM grape.process;
	
	RETURN grape.api_success('categories', _ret);
END; $$ LANGUAGE plpgsql;


