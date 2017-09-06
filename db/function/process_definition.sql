


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
			_process_role->>'role_name', 
			(_process_role->>'can_view')::BOOLEAN, 
			(_process_role->>'can_execute')::BOOLEAN,
			(_process_role->>'can_edit')::BOOLEAN
		);
	END LOOP;

	RETURN grape.api_success('process_id', _process_id);
END; $$ LANGUAGE plpgsql;


