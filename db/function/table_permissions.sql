


CREATE OR REPLACE FUNCTION grape.table_permissions_add(_schema TEXT, _tables TEXT[], _roles TEXT[], _operations TEXT[]) RETURNS INTEGER AS $$
DECLARE
	_table TEXT;
	_role TEXT;
	_op TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		FOREACH _role IN ARRAY _roles LOOP
			FOREACH _op IN ARRAY _operations LOOP
				PERFORM grape.table_permissions_add(_schema::TEXT, _table::TEXT, _role::TEXT, _op::TEXT);
			END LOOP;
		END LOOP;
	END LOOP;
	RETURN 0;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.table_permissions_add(_schema TEXT, _tables TEXT[], _roles TEXT[], _op TEXT) RETURNS INTEGER AS $$
DECLARE
	_table TEXT;
	_role TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		FOREACH _role IN ARRAY _roles LOOP
			PERFORM grape.table_permissions_add(_schema::TEXT, _table::TEXT, _role::TEXT, _op::TEXT);
		END LOOP;
	END LOOP;
	RETURN 0;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.table_permissions_add(_schema TEXT, _table TEXT, _role TEXT, _operations TEXT[]) RETURNS INTEGER AS $$
DECLARE
	_op TEXT;
BEGIN
	FOREACH _op IN ARRAY _operations LOOP
		PERFORM grape.table_permissions_add(_schema::TEXT, _table::TEXT, _role::TEXT, _op::TEXT);
	END LOOP;
	RETURN 0;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.table_permissions_add(_schema TEXT, _tables TEXT[], _role TEXT, _op TEXT) RETURNS INTEGER AS $$
DECLARE
	_table TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		PERFORM grape.table_permissions_add(_schema::TEXT, _table::TEXT, _role::TEXT, _op::TEXT);
	END LOOP;
	RETURN 0;
END; $$ LANGUAGE plpgsql;





CREATE OR REPLACE FUNCTION grape.table_permissions_add(_schema TEXT, _tablename TEXT, _rolename TEXT, _operation TEXT) RETURNS BOOLEAN AS $$
DECLARE
	_roles TEXT[];
BEGIN
	IF _operation = 'SELECT' THEN
		SELECT roles INTO _roles FROM grape.list_query_whitelist WHERE schema=_schema::TEXT AND tablename=_tablename::TEXT;
		IF NOT FOUND THEN
			INSERT INTO grape.list_query_whitelist (schema, tablename, roles)
				VALUES (_schema, _tablename, ARRAY[_rolename]::TEXT[]);
		ELSE
			IF array_position(_roles, _rolename) IS NULL THEN
				UPDATE grape.list_query_whitelist SET roles=roles || _rolename::TEXT 
					WHERE schema=_schema::TEXT AND tablename=_tablename::TEXT;
			END IF;
		END IF;
	ELSE
		SELECT roles INTO _roles FROM grape.table_operation_whitelist WHERE 
			schema=_schema::TEXT 
			AND tablename=_tablename::TEXT 
			AND allowed_operation=_operation::TEXT;

		IF NOT FOUND THEN
			INSERT INTO grape.table_operation_whitelist (schema, tablename, roles, allowed_operation)
				VALUES (_schema, _tablename, ARRAY[_rolename]::TEXT[], _operation::TEXT);
		ELSE
			IF array_position(_roles, _rolename) IS NULL THEN
				UPDATE grape.table_operation_whitelist SET roles=roles || _rolename::TEXT 
					WHERE schema=_schema::TEXT AND tablename=_tablename::TEXT AND allowed_operation=_operation::TEXT;
			END IF;
		END IF;
	END IF;
	RETURN TRUE;
END; $$ LANGUAGE plpgsql;



/**
 * Returns all permissions for the current user
 */
CREATE OR REPLACE FUNCTION grape.check_all_table_permissions () RETURNS TABLE
(
	schema TEXT, 
	tablename TEXT, 
	can_select BOOLEAN, 
	can_insert BOOLEAN, 
	can_delete BOOLEAN, 
	can_update BOOLEAN
) AS $$
DECLARE
	_rec RECORD;
	_allowed TEXT;
BEGIN
	FOR _rec IN 
			SELECT lq.schema, lq.tablename FROM grape.list_query_whitelist lq WHERE grape.current_user_in_role(lq.roles) 
		UNION 
			SELECT tw.schema, tw.tablename FROM grape.table_operation_whitelist tw WHERE grape.current_user_in_role(tw.roles) 
	LOOP
		schema := _rec.schema;
		tablename := _rec.tablename;

		can_select := FALSE;
		can_insert := FALSE;
		can_delete := FALSE;
		can_update := FALSE;

		IF EXISTS (SELECT 1 FROM grape.list_query_whitelist lq WHERE 
				lq.schema=_rec.schema 
				AND lq.tablename=_rec.tablename 
				AND grape.current_user_in_role(lq.roles)) THEN
			can_select := TRUE;
		END IF;

		FOR _allowed IN SELECT tw.allowed_operation 
			FROM grape.table_operation_whitelist tw 
			WHERE tw.schema=_rec.schema 
				AND tw.tablename=_rec.tablename 
				AND grape.current_user_in_role(tw.roles) 
		LOOP
			IF _allowed = 'INSERT' THEN
				can_insert := TRUE;
			ELSIF _allowed = 'DELETE' THEN
				can_delete := TRUE;
			ELSIF _allowed = 'UPDATE' THEN
				can_update := TRUE;
			END IF;
			
		END LOOP;

		RETURN NEXT;
	END LOOP;
END; $$ LANGUAGE plpgsql;

/**
 * Add a new entry into grape.list_query_whitelist
 */
CREATE OR REPLACE FUNCTION grape.list_query_whitelist_add(_schema TEXT, _tables TEXT[], _roles TEXT[]) RETURNS BOOLEAN AS $$
DECLARE
	_table TEXT;
BEGIN
	FOREACH _table IN ARRAY _tables LOOP
		IF EXISTS (SELECT 1 FROM grape.list_query_whitelist WHERE schema = _schema::TEXT AND tablename = _table::TEXT) THEN
			UPDATE grape.list_query_whitelist SET roles=_roles WHERE schema = _schema::TEXT AND tablename = _table::TEXT;
		ELSE
			INSERT INTO grape.list_query_whitelist(schema, tablename, roles)
				VALUES (_schema, _table, _roles);
		END IF;
	END LOOP;
	RETURN true;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.list_query_whitelist_add (_schema TEXT, _tables TEXT[]) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	RETURN grape.list_query_whitelist_add(_schema, _tables, '{all}'::TEXT[]);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.list_query_whitelist_delete(_schema TEXT, _tablename TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	DELETE FROM grape.list_query_whitelist WHERE schema = _schema::TEXT AND tablename = _tablename::TEXT;
	RETURN TRUE;
END; $$ LANGUAGE plpgsql;

-- Check permission on a table for current user
CREATE OR REPLACE FUNCTION grape.list_query_check_permission (_schema TEXT, _tablename TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	IF EXISTS (SELECT 1 FROM grape.list_query_whitelist WHERE schema=_schema::TEXT AND tablename = _tablename::TEXT AND grape.current_user_in_role(roles)) THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END; $$ LANGUAGE plpgsql;




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

	IF _operation = 'SELECT' THEN
		IF grape.list_query_check_permission(_schema, _tablename) = TRUE THEN
			RETURN NULL;
		ELSE
			RETURN grape.api_error('Permission denied to table ' || _schema::TEXT || '.' || _tablename::TEXT, 
				-2
			);
		END IF;

	END IF;

	SELECT roles INTO _roles FROM grape.table_operation_whitelist WHERE 
		schema = _schema::TEXT 
		AND _tablename::TEXT ~ tablename 
		AND _operation ~ allowed_operation;

	IF NOT FOUND THEN
		RETURN grape.api_error(FORMAT('You do not have the necessary permissions to perform a %s operation on the table %s.%s', _operation, _schema, _tablename), -2);
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




