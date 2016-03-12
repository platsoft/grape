

CREATE OR REPLACE FUNCTION grape.save_report (_name TEXT, _function_schema TEXT, _function_name TEXT, _input_fields JSON) RETURNS INTEGER AS $$
DECLARE
	_report_id INTEGER;
BEGIN
	IF EXISTS (SELECT 1 FROM grape.report WHERE name=_name) THEN
		UPDATE grape.report SET 
			function_schema=_function_schema, 
			function_name=_function_name,
			input_fields=_input_fields 
			WHERE name=_name 
			RETURNING report_id INTO _report_id;
	ELSE
		INSERT INTO grape.report (name, function_schema, function_name, input_fields)
			VALUES (_name, _function_schema, _function_name, _input_fields);
	END IF;

	RETURN _report_id;
END; $$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.execute_report (_name TEXT, _parameters JSON) RETURNS JSON AS $$
DECLARE
	_sql TEXT;
	_report RECORD;
	_result JSON;
	
	_function_info RECORD;

	_dtype TEXT;
BEGIN
	SELECT * INTO _report FROM grape.report WHERE name=_name::TEXT;
	
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


