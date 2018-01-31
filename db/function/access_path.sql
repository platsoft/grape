
/**
 * Input: path TEXT regex of path to match
 * Input: roles TEXT[] list of role names
 * Input: methods TEXT[] list of methods (must be GET, POST or PUT)
 */
CREATE OR REPLACE FUNCTION grape.add_access_path(JSON) RETURNS JSON AS $$
DECLARE
	_path TEXT;
	_roles TEXT[];
	_methods TEXT[];

	_m TEXT;
BEGIN

	_path := $1->>'path';
	_roles := ($1->>'roles')::TEXT[];
	_methods := ($1->>'methods')::TEXT[];

	FOREACH _m IN ARRAY _methods LOOP
		IF _m NOT IN (
			'GET', 
			'POST', 
			'PUT',
			'HEAD',
			'DELETE',
			'OPTIONS',
			'MKCOL',
			'LOCK',
			'CONNECT',
			'PATCH',
			'COPY',
			'MOVE',
			'PROPFIND',
			'PROPPATCH',
			'UNLOCK'
		) THEN
			RETURN grape.api_error_invalid_input();
		END IF;
	END LOOP;

	PERFORM grape.add_access_path (_path, _roles, _methods);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.add_access_path (_path TEXT, _roles TEXT[], _methods TEXT[]) RETURNS INTEGER AS $$
DECLARE
	_role TEXT;
BEGIN
	
	FOREACH _role IN ARRAY _roles LOOP
		IF NOT EXISTS  (SELECT 1 FROM grape.access_role WHERE role_name=_role::TEXT) THEN
			INSERT INTO grape.access_role (role_name) VALUES (_role);
		END IF;

		IF EXISTS (SELECT 1 FROM grape.access_path WHERE role_name=_role::TEXT AND regex_path=_path::TEXT) THEN
			UPDATE grape.access_path SET method=_methods WHERE role_name=_role::TEXT AND regex_path=_path::TEXT;
		ELSE
			INSERT INTO grape.access_path (role_name, regex_path, method)
				VALUES (_role, _path, _methods);
		END IF;
	END LOOP;

	RETURN 0;
END; $$ LANGUAGE plpgsql;


