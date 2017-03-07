/**
 * THE FUNCTIONS IN THIS FILE IS STILL A WORK IN PROGRESS
 */
CREATE OR REPLACE FUNCTION grape.insert_query_whitelist_add(_schema TEXT, _tables TEXT[], _roles TEXT[]) RETURNS BOOLEAN AS $$
DECLARE
	_table TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		IF EXISTS (SELECT 1 FROM grape.insert_query_whitelist WHERE schema = _schema::TEXT AND tablename = _table::TEXT) THEN
			UPDATE grape.insert_query_whitelist SET roles=_roles WHERE schema = _schema::TEXT AND tablename = _table::TEXT;
		ELSE
			INSERT INTO grape.insert_query_whitelist(schema, tablename, roles)
				VALUES (_schema, _table, _roles);
		END IF;
	END LOOP;
	RETURN true;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.insert_query_whitelist_add (_schema TEXT, _tables TEXT[]) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	RETURN grape.insert_query_whitelist_add(_schema, _tables, '{all}'::TEXT[]);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.insert_query_whitelist_delete(_schema TEXT, _tablename TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	DELETE FROM grape.insert_query_whitelist WHERE schema = _schema::TEXT and tablename = _tablename::TEXT;
	RETURN TRUE;
END; $$ LANGUAGE plpgsql;


/**
 * Input fields:
 * 	tablename
 * 	schema (optional) text
 */
CREATE OR REPLACE FUNCTION grape.insert_query(JSON) RETURNS JSON AS $$
DECLARE
	_sql TEXT;
	_tablename TEXT;
	_roles TEXT[];
	_schema TEXT;
	_columns_sql TEXT[];
	_values_sql TEXT[];
	_user_roles TEXT[];
	_ret JSON;
	_values JSON;
	_rec RECORD;
	_returning TEXT;
BEGIN
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN grape.api_error('Table requested is null', -5);
	END IF;

	_tablename := $1->>'tablename';

	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
	END IF;

	/*
	SELECT roles INTO _roles FROM grape.insert_query_whitelist WHERE schema = _schema::TEXT AND _tablename::TEXT ~ tablename;
	IF NOT FOUND THEN
		RETURN grape.api_error('Table requested is not in whitelist', -2);
	END IF;

	IF NOT _roles @> '{all}' AND grape.current_user_in_role(_roles) = FALSE THEN
		SELECT array_agg(c) INTO _user_roles FROM grape.current_user_roles() c;
		RETURN grape.api_error('Permission denied to table ' || _schema::TEXT || '.' || _tablename::TEXT, 
			-2, 
			json_build_object('allowed_roles', _roles, 'user_roles', _user_roles)
		);
	END IF;
	*/
	
	_columns_sql := ARRAY[]::TEXT[];
	_values_sql := ARRAY[]::TEXT[];
	
	_values := $1->'values';
	IF _values IS NULL THEN
		RETURN grape.api_error('Invalid input parameters', -2);
	END IF;

	FOR _rec IN SELECT 
			column_name, 
			column_default, 
			is_nullable, 
			data_type 
		FROM 
			information_schema.columns 
		WHERE 
			table_schema=_schema::TEXT 
			AND table_name=_tablename::TEXT
	LOOP
		RAISE NOTICE 'rec: %', _rec;
		_columns_sql := ARRAY_APPEND(_columns_sql, quote_ident(_rec.column_name));
		IF json_extract_path_text(_values, _rec.column_name) IS NULL THEN
			IF _rec.column_default IS NOT NULL THEN
				_values_sql := ARRAY_APPEND(_values_sql, (_rec.column_default)::TEXT);
			ELSE
				IF _rec.is_nullable = 'NO' THEN
					RETURN grape.api_error('The column ' || _rec.column_name || ' cannot be NULL', -12);
				ELSE
					_values_sql := ARRAY_APPEND(_values_sql, 'NULL');
				END IF;
			END IF;
		ELSE
			_values_sql := ARRAY_APPEND(_values_sql, quote_nullable(json_extract_path_text(_values, _rec.column_name)) || '::' || _rec.data_type);
		END IF;
	END LOOP;

	IF json_extract_path_text($1, 'returning') IS NOT NULL THEN
		_returning := 'RETURNING ' || quote_ident($1->>'returning');
	ELSE
		_returning := '';
	END IF;

	_sql := format('INSERT INTO %I.%I (%s) VALUES (%s) %s', _schema, _tablename, array_to_string(_columns_sql, ', '), array_to_string(_values_sql, ', ', 'NULL'), _returning);
	RAISE NOTICE 'SQL: %', _sql;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

-- SELECT grape.insert_query('{"tablename":"user","schema":"grape","values":{"username":"Piet","password":"aaa"},"returning":"user_id"}'::JSON);


