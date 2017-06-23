
/**
 * Input: role_name
 */
CREATE OR REPLACE FUNCTION grape.add_access_role(JSON) RETURNS JSON AS $$
DECLARE
	_role_name TEXT;
BEGIN
	_role_name := ($1->>'role_name');
	PERFORM grape.add_access_role(_role_name);
	RETURN grape.api_success('role_name', _role_name);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.add_access_role(_role_name TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	IF NOT EXISTS (SELECT 1 FROM grape.access_role WHERE role_name=_role_name::TEXT) THEN
		INSERT INTO grape.access_role(role_name) VALUES (_role_name);
	END IF;
END; $$ LANGUAGE plpgsql;

