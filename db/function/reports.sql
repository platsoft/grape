

CREATE OR REPLACE FUNCTION grape.save_report (_report_id INTEGER, _name TEXT, _function_schema TEXT, _function_name TEXT, _input_fields JSON) RETURNS INTEGER AS $$
DECLARE
	_new_report_id INTEGER;
BEGIN
	IF _report_id IS NOT NULL THEN
		UPDATE grape.report SET 
			name=_name,
			function_schema=_function_schema, 
			function_name=_function_name,
			input_fields=_input_fields 
			WHERE report_id=_report_id::INTEGER
			RETURNING report_id INTO _new_report_id;
	ELSE
		INSERT INTO grape.report (name, function_schema, function_name, input_fields)
			VALUES (_name, _function_schema, _function_name, _input_fields)
			RETURNING report_id INTO _new_report_id;
	END IF;

	RETURN _report_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.save_report (JSON) RETURNS JSON AS $$
DECLARE
	_report_id INTEGER;
	_name TEXT;
	_function_name TEXT;
	_function_schema TEXT;
	_input_fields JSON;
BEGIN
	
	IF json_extract_path($1, 'report_id') IS NOT NULL THEN
		_report_id := ($1->>'report_id')::INTEGER;
	END IF;

	_name := $1->>'name';
	_function_name := $1->>'function_name';
	_function_schema := $1->>'function_schema';
	_input_fields := $1->'input_fields';

	_report_id := grape.save_report (_report_id, _name, _function_name, _function_schema, _input_fields);
	
	RETURN grape.api_success('report_id', _report_id);
END; $$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION grape.execute_report (_report_id INTEGER, _parameters JSON) RETURNS JSON AS $$
DECLARE
	_sql TEXT;
	_report RECORD;
	_result JSON;
	
	_function_info RECORD;

	_dtype TEXT;
BEGIN
	SELECT * INTO _report FROM grape.report WHERE report_id=_report_id::INTEGER;
	
	SELECT * FROM information_schema.routines INTO _function_info WHERE routine_schema=_report.function_schema AND routine_name=_report.function_name;

	_dtype := LOWER(_function_info.data_type);

	IF _dtype = 'json' THEN
		_sql := CONCAT('SELECT ', 
			quote_ident(_report.function_schema), 
			'.', 
			quote_ident(_report.function_name),
			'(%::JSON) AS a');

	ELSIF _dtype = 'user-defined' THEN

		_sql := CONCAT('SELECT json_build_object(''result'', json_agg(a)) FROM ', 
			quote_ident(_report.function_schema), 
			'.', 
			quote_ident(_report.function_name),
			'(%::JSON) AS a');

	ELSIF _dtype = 'record' THEN

		_sql := CONCAT('SELECT json_build_object(''result'', json_agg(a)) FROM ', 
			quote_ident(_report.function_schema), 
			'.', 
			quote_ident(_report.function_name),
			'(%::JSON) AS a');
	ELSE

		_sql := CONCAT('SELECT json_build_object(''result'', to_json(a)) FROM ', 
			quote_ident(_report.function_schema), 
			'.', 
			quote_ident(_report.function_name),
			'(%::JSON) AS a');

	END IF;
	
	EXECUTE _sql USING _parameters INTO _result;

	RETURN _result;
END; $$ LANGUAGE plpgsql;

/**
 * JSON object needs name field (with report name) and optional JSON params
 */
CREATE OR REPLACE FUNCTION grape.execute_report (JSON) RETURNS JSON AS $$
DECLARE
	_name TEXT;
	_report_id INTEGER;
	_parameters JSON;
BEGIN
	IF json_extract_path($1, 'name') IS NOT NULL THEN
		_name := $1->>'name';
		_report_id := (SELECT report_id FROM grape.report WHERE name=_name::TEXT);
	ELSE
		_report_id := ($1->>'report_id')::INTEGER;
	END IF;

	IF json_extract_path ($1, 'params') IS NULL THEN
		_parameters := '{}'::JSON;
	ELSE
		_parameters := $1->'params';
	END IF;
	RETURN grape.execute_report(_report_id, _parameters);
END; $$ LANGUAGE plpgsql;



