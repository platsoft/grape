/**
 * Input schema Schema name
 * Input tables Array of table names
 * Input roles Array of role names
 * Input allowed_operation Operation to allow, must be one of INSERT, UPDATE or DELETE
 */
CREATE OR REPLACE FUNCTION grape.table_operation_whitelist_add(_schema TEXT, _tables TEXT[], _roles TEXT[], _allowed_operation TEXT) RETURNS BOOLEAN AS $$
DECLARE
	_table TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		IF EXISTS (SELECT 1 FROM grape.table_operation_whitelist WHERE 
				schema = _schema::TEXT 
				AND tablename = _table::TEXT 
				AND allowed_operation=_allowed_operation::TEXT
			) THEN
				UPDATE grape.table_operation_whitelist 
					SET 
						roles=_roles
					WHERE 
						schema = _schema::TEXT 
						AND tablename = _table::TEXT
						AND allowed_operation = _allowed_operation::TEXT;

		ELSE
			INSERT INTO grape.table_operation_whitelist(schema, tablename, roles, allowed_operation)
				VALUES (_schema, _table, _roles, _allowed_operation);
		END IF;
	END LOOP;
	RETURN true;
END; $$ LANGUAGE plpgsql;

/**
 * Removes table from insert query whitelist
 */
CREATE OR REPLACE FUNCTION grape.table_operation_whitelist_delete(_schema TEXT, _tablename TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	DELETE FROM grape.table_operation_whitelist WHERE schema = _schema::TEXT AND tablename = _tablename::TEXT;
	RETURN TRUE;
END; $$ LANGUAGE plpgsql;

-- Checks permissions against current user
-- returns NULL if allowed, and grape return if error
CREATE OR REPLACE FUNCTION grape.table_operation_check_permissions (_schema TEXT, _tablename TEXT, _operation TEXT) RETURNS JSON AS $$
DECLARE
	_roles TEXT[];
	_user_roles TEXT[];
BEGIN
	SELECT roles INTO _roles FROM grape.table_operation_whitelist WHERE 
		schema = _schema::TEXT 
		AND _tablename::TEXT ~ tablename 
		AND _operation ~ allowed_operation;

	IF NOT FOUND THEN
		RETURN grape.api_error(FORMAT('Table requested (%s.%s) is not in %s whitelist', _schema, _tablename, _operation), -2);
	END IF;

	IF NOT _roles @> '{all}' AND grape.current_user_in_role(_roles) = FALSE THEN
		SELECT array_agg(c) INTO _user_roles FROM grape.current_user_roles() c;
		RETURN grape.api_error('Permission denied to table ' || _schema::TEXT || '.' || _tablename::TEXT, 
			-2, 
			json_build_object('allowed_roles', _roles, 'user_roles', _user_roles)
		);
	END IF;

	RETURN NULL;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.build_filter_sql (_schema TEXT, _tablename TEXT, _filter JSON) RETURNS TEXT AS $$
DECLARE
	_rec RECORD;
	_filter_operator TEXT;
	_filter_value TEXT;
	_filter_sql TEXT[] := ARRAY[]::TEXT[];
	_build_sql TEXT;
BEGIN
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
		-- RAISE NOTICE 'rec: %', _rec;
		IF json_extract_path_text(_filter, _rec.column_name) IS NOT NULL THEN
			_filter_value := json_extract_path_text(_filter, _rec.column_name);
			
			_filter_operator := '=';

			IF _filter_value LIKE 'LIKE %' THEN
				_filter_operator := 'LIKE';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 6));
			ELSIF _filter_value LIKE '>=%' THEN
				_filter_operator := '>=';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 3));
			ELSIF _filter_value LIKE '!=%' THEN
				_filter_operator := '!=';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 3));
			ELSIF _filter_value LIKE '<=%' THEN
				_filter_operator := '<=';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 3));
			ELSIF _filter_value LIKE '>%' THEN
				_filter_operator := '>';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 2));
			ELSIF _filter_value LIKE '<%' THEN
				_filter_operator := '<';
				_filter_value := TRIM(SUBSTRING(_filter_value FROM 2));
			END IF;

			_build_sql := CONCAT('(', quote_ident(_rec.column_name), _filter_operator, quote_nullable(_filter_value), '::', _rec.data_type, ')');

			_filter_sql := ARRAY_APPEND(_filter_sql, _build_sql);
		END IF;
	END LOOP;

	RETURN array_to_string(_filter_sql, ' AND ');
END; $$ LANGUAGE plpgsql;

/**
 * Input fields:
 * 	tablename
 * 	schema (optional) text
 *	values JSON
 *	returning TEXT Column to return, or * to get all
 */
CREATE OR REPLACE FUNCTION grape.insert_record(JSON) RETURNS JSON AS $$
DECLARE
	_sql TEXT;
	_tablename TEXT;
	_schema TEXT;
	_columns_sql TEXT[];
	_values_sql TEXT[];
	_perm_check JSON;

	_ret_value JSON;
	
	_ret JSON;

	_values JSON;
	_rec RECORD;

	_returning_sql TEXT;
	_returning_column TEXT;
BEGIN
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN grape.api_error('Table requested is null', -5);
	END IF;

	_tablename := $1->>'tablename';

	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
	END IF;

	_perm_check := grape.table_operation_check_permissions(_schema, _tablename, 'INSERT');
	IF _perm_check IS NOT NULL THEN
		RETURN _perm_check;
	END IF;

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
		-- RAISE NOTICE 'rec: %', _rec;
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
		_returning_column := $1->>'returning';
		IF _returning_column = '*' THEN
			_returning_sql := 'RETURNING ' || ($1->>'returning');
		ELSE
			_returning_sql := 'RETURNING ' || quote_ident($1->>'returning');
		END IF;
	ELSE
		_returning_column := NULL;
		_returning_sql := '';
	END IF;

	_sql := format('INSERT INTO %I.%I (%s) VALUES (%s) %s', 
		_schema, 
		_tablename, 
		array_to_string(_columns_sql, ', '), 
		array_to_string(_values_sql, ', ', 'NULL'), 
		_returning_sql
	);

	-- RAISE NOTICE 'SQL: %', _sql;

	EXECUTE _sql INTO _rec; -- ret_value;

	_ret_value := to_json(_rec);

	IF _returning_column IS NULL THEN
		RETURN grape.api_success();
	ELSE
		RETURN grape.api_success('return', _ret_value);
	END IF;
END; $$ LANGUAGE plpgsql;



/**
 * Delete value from table
 * Input schema TEXT
 * Input tablename TEXT
 * Input filter JSON
 */
CREATE OR REPLACE FUNCTION grape.delete_record(JSON) RETURNS JSON AS $$
DECLARE
	_tablename TEXT;
	_schema TEXT;
	_ret JSON;

	_filter JSON;
	_filter_sql TEXT;
	_perm_check JSON;

	_build_sql TEXT;
	
	_sql TEXT;

	_rec RECORD;
BEGIN
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN grape.api_error('Table requested is null', -5);
	END IF;

	_tablename := $1->>'tablename';

	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
	END IF;

	_perm_check := grape.table_operation_check_permissions(_schema, _tablename, 'DELETE');
	IF _perm_check IS NOT NULL THEN
		RETURN _perm_check;
	END IF;
	
	_filter := $1->'filter';
	IF _filter IS NULL THEN
		RETURN grape.api_error('Invalid input parameters (missing filter)', -2);
	END IF;

	_filter_sql := grape.build_filter_sql(_schema, _tablename, _filter);
	
	-- RAISE NOTICE 'Filter SQL: %', _filter_sql;

	_sql := FORMAT('DELETE FROM %I.%I WHERE %s', _schema, _tablename, _filter_sql);
	-- RAISE NOTICE 'SQL: %', _sql;

	EXECUTE _sql;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

/**
 * Input fields:
 * 	tablename
 * 	schema (optional) text
 *	values JSON
 *	filter JSON
 *	returning TEXT Column to return, or * to get all
 */
CREATE OR REPLACE FUNCTION grape.update_record(JSON) RETURNS JSON AS $$
DECLARE
	_sql TEXT;
	_tablename TEXT;
	_schema TEXT;
	_updates_sql TEXT[];
	_build_sql TEXT;
	_perm_check JSON;
	_filter JSON;
	_filter_sql TEXT;

	_ret_value JSON;
	
	_ret JSON;

	_values JSON;
	_rec RECORD;

	_returning_sql TEXT;
	_returning_column TEXT;
BEGIN
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN grape.api_error('Table requested is null', -5);
	END IF;

	_tablename := $1->>'tablename';

	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
	END IF;

	_perm_check := grape.table_operation_check_permissions(_schema, _tablename, 'UPDATE');
	IF _perm_check IS NOT NULL THEN
		RETURN _perm_check;
	END IF;

	_updates_sql := ARRAY[]::TEXT[];
	
	_values := $1->'values';
	IF _values IS NULL THEN
		RETURN grape.api_error('Invalid input parameters', -2);
	END IF;

	_filter := $1->'filter';
	IF _filter IS NULL THEN
		RETURN grape.api_error('Invalid input parameters (missing filter)', -2);
	END IF;

	_filter_sql := grape.build_filter_sql(_schema, _tablename, _filter);


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
		-- RAISE NOTICE 'rec: %', _rec;
		IF json_extract_path(_values, _rec.column_name) IS NOT NULL THEN
			_build_sql := CONCAT(
				quote_ident(_rec.column_name), 
				'=',
				quote_nullable(json_extract_path_text(_values, _rec.column_name)),
				'::',
				_rec.data_type);
			_updates_sql := ARRAY_APPEND(_updates_sql, _build_sql);
		END IF;
		
	END LOOP;

	IF json_extract_path_text($1, 'returning') IS NOT NULL THEN
		_returning_column := $1->>'returning';
		IF _returning_column = '*' THEN
			_returning_sql := 'RETURNING ' || ($1->>'returning');
		ELSE
			_returning_sql := 'RETURNING ' || quote_ident($1->>'returning');
		END IF;
	ELSE
		_returning_column := NULL;
		_returning_sql := '';
	END IF;

	_sql := format('UPDATE %I.%I SET %s WHERE %s %s', 
		_schema, 
		_tablename, 
		array_to_string(_updates_sql, ', '), 
		_filter_sql,
		_returning_sql
	);

	-- RAISE NOTICE 'SQL: %', _sql;

	EXECUTE _sql INTO _rec; -- ret_value;

	_ret_value := to_json(_rec);

	IF _returning_column IS NULL THEN
		RETURN grape.api_success();
	ELSE
		RETURN grape.api_success('return', _ret_value);
	END IF;
END; $$ LANGUAGE plpgsql;

/*
SELECT grape.table_operation_whitelist_add('grape', ARRAY['user']::TEXT[], ARRAY['all']::TEXT[], 'INSERT');
SELECT grape.table_operation_whitelist_add('grape', ARRAY['user']::TEXT[], ARRAY['all']::TEXT[], 'DELETE');
SELECT grape.table_operation_whitelist_add('grape', ARRAY['user']::TEXT[], ARRAY['all']::TEXT[], 'UPDATE');

SELECT grape.insert_record('{"tablename":"user","schema":"grape","values":{"username":"Piet","password":"aaa"},"returning":"user_id"}'::JSON);
SELECT grape.insert_record('{"tablename":"user","schema":"grape","values":{"username":"Jan","password":"aaa"},"returning":"*"}'::JSON);

SELECT grape.update_record('{"tablename":"user","schema":"grape","filter":{"username":"Jan"},"values":{"password":"abc"},"returning":"*"}'::JSON);

SELECT grape.delete_record('{"tablename":"user","schema":"grape","filter":{"username":"Piet"}}'::JSON);
SELECT grape.delete_record('{"tablename":"user","schema":"grape","filter":{"password":"abc"}}'::JSON);

SELECT grape.table_operation_whitelist_delete('grape', 'user');
*/

