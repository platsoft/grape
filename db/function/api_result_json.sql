
DROP TYPE IF EXISTS grape.grape_result_type CASCADE;
CREATE TYPE grape.grape_result_type AS
(
	success BOOLEAN,
	reason TEXT,
	data JSON
);


/**
 * Construct a JSON object with 3 fields, status, code and message. status is set to ERROR, message to the value of the _message parameter and code to the _code parameter. If _code is NULL this parameter is ignored
 */
CREATE OR REPLACE FUNCTION grape.api_result_error(_message TEXT, _code INTEGER, _error JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	IF _code IS NULL THEN
		RETURN json_build_object('status', 'ERROR', 'message', _message, 'error', _error);
	ELSE
		RETURN json_build_object('status', 'ERROR', 'message', _message, 'code', _code, 'error', _error);
	END IF;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error(_message TEXT, _code INTEGER, _error JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error(_message, _code, _error);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error() RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('Unknown error', -1);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error_invalid_input(_info JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('Invalid input', -3, _info);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error_invalid_field(_name TEXT) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('Missing or invalid field: ' || _name, -3, '{}'::JSON);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.api_error_permission_denied(_info JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('Permission denied', -2, _info);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error_data_not_found(_info JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('Data not found', -5, _info);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_error_invalid_data_state(_info JSON DEFAULT '{}'::JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_result_error('The operation requested could not be performed on the data because the data is not in a valid state', -6, _info);
END; $$ LANGUAGE plpgsql;





CREATE OR REPLACE FUNCTION grape.api_success(_keys TEXT[], _values TEXT[], _types TEXT[]) RETURNS JSON AS $$
DECLARE
	_ret JSON;
	_i INTEGER;
	_key TEXT;
	_value TEXT;
	_sql TEXT;
	_type TEXT;
BEGIN
	-- TODO look at the speed of this concatenations (maybe use CONCAT?)
	_i := 1;

	_sql := 'SELECT to_json(b) FROM (SELECT ''OK'' AS "status" ';

	WHILE _i <= array_length(_keys, 1) LOOP
		_key := _keys[_i];
		_value := _values[_i];
		_type := _types[_i];

		_sql := _sql || ', ';

		IF _value IS NULL THEN
			_sql := _sql || 'null';
		ELSE
			IF _type = 'i' OR _type = 'integer' OR _type = 'number' OR _type = 'n' THEN
				_sql := _sql || _value;
			ELSIF _type = 'json' OR _type = 'j' THEN
				_sql := _sql || quote_literal(_value) || '::JSON';
			ELSE
				_sql := _sql || quote_literal(_value);
			END IF;
		END IF;

		_sql := _sql || ' AS ' || quote_ident(_key);

		_i := _i + 1;
	END LOOP;

	_sql := _sql || ' ) AS b';

	-- RAISE NOTICE 'SQL: %', _sql;
	EXECUTE _sql INTO _ret;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(_keys TEXT[], _values INTEGER[]) RETURNS JSON AS $$
DECLARE
	_types TEXT[];
BEGIN
	_types := array_fill('n'::TEXT, ARRAY[array_length(_values, 1)]);

	RETURN grape.api_success(_keys, _values::TEXT[], ARRAY['n']);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(_key1 TEXT, _val1 INTEGER) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_success(ARRAY[_key1]::TEXT[], ARRAY[_val1::TEXT]::TEXT[], ARRAY['n']);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(_key1 TEXT, _val1 INTEGER, _key2 TEXT, _val2 INTEGER) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_success(ARRAY[_key1, _key2]::TEXT[], ARRAY[_val1::TEXT, _val2::TEXT]::TEXT[], ARRAY['n', 'n']);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(_key1 TEXT, _val1 JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_success(ARRAY[_key1]::TEXT[], ARRAY[_val1::TEXT]::TEXT[], ARRAY['j']);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.api_success() RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	SELECT to_json(b) INTO _ret FROM (SELECT 'OK' AS "status") AS b;
	RETURN _ret;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN (jsonb_build_object('status', 'OK') || $1::JSONB)::JSON;
END; $$ LANGUAGE plpgsql;

/**
 * Returns success message when data is not null, otherwise it returns grape.api_error_data_not_found
 */
CREATE OR REPLACE FUNCTION grape.api_success_if_not_null(_fieldname TEXT, _data JSON) RETURNS JSON AS $$
	SELECT 
		CASE WHEN _data IS NULL OR json_typeof(_data) = 'null' THEN 
			grape.api_error_data_not_found() 
		ELSE 
			grape.api_success(_data)
		END;
$$ LANGUAGE sql;



CREATE OR REPLACE FUNCTION grape.api_result(res grape.grape_result_type) RETURNS JSON AS $$
DECLARE
	_code INTEGER;
BEGIN
	IF res.success = false THEN
		_code := -1;
		IF json_extract_path(res.data, 'code') IS NOT NULL THEN
			_code := (res.data->>'code')::INTEGER;
		END IF;

		RETURN grape.api_error(res.reason, _code);
	ELSIF res.success = true THEN
		RETURN grape.api_success('data', res.data);
	END IF;
	
	RETURN grape.api_error();
END; $$ LANGUAGE plpgsql;



