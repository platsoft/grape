
CREATE OR REPLACE FUNCTION grape.save_process_definition(JSONB) RETURNS JSONB AS $$
DECLARE
	_process_name TEXT;
	_description TEXT;
	_process_id INTEGER;
	_process_category TEXT;
	_process_type TEXT;
	_pg_function TEXT;
	_function_schema TEXT;
	_process_role JSONB;
	_role JSONB;
	_ui_param JSON;

	_start_function_name TEXT;
	_start_function_schema TEXT;
	_end_function_name TEXT;
	_end_function_schema TEXT;
	_error_function_name TEXT;
	_error_function_schema TEXT;
BEGIN
	_process_id := ($1->>'process_id')::INTEGER;
	_pg_function := ($1->>'pg_function');
	_description := ($1->>'description');
	_ui_param := $1->'param';
	_process_type := ($1->>'process_type');
	_function_schema := ($1->>'function_schema');
	_process_category := ($1->>'process_category');

	_process_role := ($1->'process_role');

	_process_name := ($1->>'process_name');

	-- TODO validation, make sure process_type is one of DB, EXEC or NODE

	IF $1 ? 'start_function_name' AND $1 ? 'start_function_schema' THEN
		_start_function_name := $1->>'start_function_name';
		_start_function_schema := $1->>'start_function_schema';
	END IF;
	IF $1 ? 'end_function_name' AND $1 ? 'end_function_schema' THEN
		_end_function_name := $1->>'end_function_name';
		_end_function_schema := $1->>'end_function_schema';
	END IF;
	IF $1 ? 'error_function_name' AND $1 ? 'error_function_schema' THEN
		_error_function_name := $1->>'error_function_name';
		_error_function_schema := $1->>'error_function_schema';
	END IF;

	IF _process_id IS NULL THEN
		INSERT INTO grape.process (
			process_name,
			pg_function,
			description,
			ui_param,
			process_type,
			function_schema,
			process_category
		) VALUES (
			_process_name,
			_pg_function,
			_description,
			_ui_param,
			_process_type,
			_function_schema,
			_process_category
		) RETURNING process_id INTO _process_id;
	ELSE
		UPDATE grape.process SET
			process_name=_process_name,
			pg_function=_pg_function,
			description=_description,
			ui_param=_ui_param,
			process_type=_process_type,
			function_schema=_function_schema,
			process_category=_process_category
		WHERE process_id=_process_id::INTEGER;
	END IF;

	IF _start_function_name IS NOT NULL THEN
		UPDATE grape.process SET 
			start_function_name=_start_function_name,
			start_function_schema=_start_function_schema
		WHERE process_id=_process_id::INTEGER;
	END IF;
	IF _end_function_name IS NOT NULL THEN
		UPDATE grape.process SET 
			end_function_name=_end_function_name,
			end_function_schema=_end_function_schema
		WHERE process_id=_process_id::INTEGER;
	END IF;
	IF _error_function_name IS NOT NULL THEN
		UPDATE grape.process SET 
			error_function_name=_error_function_name,
			error_function_schema=_error_function_schema
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

DROP FUNCTION IF EXISTS grape.upsert_process(TEXT,TEXT,JSON,TEXT,TEXT,TEXT);
CREATE OR REPLACE FUNCTION grape.upsert_process(
	_pg_function TEXT,
	_description TEXT,
	_ui_param JSON,
	_process_type TEXT,
	_function_schema TEXT,
	_process_category TEXT) RETURNS VOID AS $$

	INSERT INTO grape.process (
		process_name,
		pg_function,
		description,
		ui_param,
		process_type,
		function_schema,
		process_category
	)
	VALUES (
		_pg_function,
		_pg_function,
		_description,
		_ui_param,
		_process_type,
		COALESCE(_function_schema, ''),
		_process_category
	)
	ON CONFLICT (process_name) --if processing_function name is the same update all the other values
	DO UPDATE SET
		pg_function=EXCLUDED.pg_function,
		description=EXCLUDED.description,
		ui_param=EXCLUDED.ui_param,
		process_type=EXCLUDED.process_type,
		function_schema=EXCLUDED.function_schema,
		process_category=EXCLUDED.process_category;

$$ LANGUAGE sql;

DROP FUNCTION IF EXISTS grape.upsert_process(TEXT,TEXT,TEXT,JSON,TEXT,TEXT,TEXT);
CREATE OR REPLACE FUNCTION grape.upsert_process(
	_process_name TEXT,
	_pg_function TEXT,
	_description TEXT,
	_ui_param JSON,
	_process_type TEXT,
	_function_schema TEXT,
	_process_category TEXT) RETURNS VOID AS $$

	INSERT INTO grape.process (
		process_name,
		pg_function,
		description,
		ui_param,
		process_type,
		function_schema,
		process_category
	)
	VALUES (
		_process_name,
		_pg_function,
		_description,
		_ui_param,
		_process_type,
		COALESCE(_function_schema, ''),
		_process_category
	)
	ON CONFLICT (process_name) --if processing_function name is the same update all the other values
	DO UPDATE SET
		pg_function=EXCLUDED.pg_function,
		description=EXCLUDED.description,
		ui_param=EXCLUDED.ui_param,
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
			ap.ui_param,
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



