
/** 
 * Construct a JSON object with 3 fields, status, code and message. status is set to ERROR, message to the value of the _message parameter and code to the _code parameter. If _code is NULL this parameter is ignored
 */
CREATE OR REPLACE FUNCTION grape.api_result_error(_message TEXT, _code INTEGER) RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	IF _code IS NULL THEN
		SELECT to_json(b) INTO _ret FROM 
			(SELECT 'ERROR' AS "status", _message AS "message") AS b;
	ELSE
		SELECT to_json(b) INTO _ret FROM 
			(SELECT 'ERROR' AS "status", _message AS "message", _code AS "code") AS b;
	END IF;

	RETURN _ret;
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
	_i := 1;

	_sql := 'SELECT to_json(b) FROM (SELECT ''OK'' AS "status" ';

	WHILE _i <= array_length(_keys, 1) LOOP
		_key := _keys[_i];
		_value := _values[_i];
		_type := _types[_i];

		_sql := _sql || ', ';

		IF _type = 'i' OR _type = 'integer' OR _type = 'number' OR _type = 'n' THEN
			_sql := _sql || _value;
		ELSE
			_sql := _sql || quote_literal(_value);
		END IF;
		_sql := _sql || ' AS ' || quote_ident(_key);

		_i := _i + 1;
	END LOOP;

	_sql := _sql || ' ) AS b';

	RAISE NOTICE 'SQL: %', _sql;
	EXECUTE _sql INTO _ret;
	
	RETURN _ret;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.api_success(_keys TEXT[], _values INTEGER[]) RETURNS JSON AS $$
DECLARE
	_types TEXT[];
BEGIN
	_types := array_fill('n'::TEXT, ARRAY[array_length(_values, 1)]);

	RETURN grape.api_success(_keys, _values::TEXT[], ARRAY['n']);
	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.api_success() RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	SELECT to_json(b) INTO _ret FROM (SELECT 'OK' AS "status") AS b;
	RETURN _ret;
END; $$ LANGUAGE plpgsql;


