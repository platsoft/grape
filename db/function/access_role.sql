
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
	RETURN _role_name;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.add_access_role_to_role(_child_role TEXT, _parent_role TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	IF EXISTS (SELECT 1 FROM grape.get_role_roles(_parent_role) g WHERE g=_child_role) THEN
		RAISE EXCEPTION 'Unable to add % to %. Access role % is a child of %', _child_role, _parent_role, _parent_role, _child_role;
		RETURN NULL;
	END IF;
	IF NOT EXISTS (SELECT 1 FROM grape.access_role_role WHERE parent_role_name=_parent_role::TEXT AND child_role_name=_child_role::TEXT) THEN
		INSERT INTO grape.access_role_role(child_role_name, parent_role_name) VALUES (_child_role, _parent_role);
	END IF;
	RETURN _parent_role;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.get_role_roles(_role_name TEXT) RETURNS SETOF TEXT AS $$
	WITH RECURSIVE rec_roles(role_name) AS (
		SELECT _role_name AS role_name
			UNION ALL
		SELECT parent_role_name FROM 
			grape.access_role_role arr, 
			rec_roles rur 
			WHERE arr.child_role_name=rur.role_name
	)
	SELECT DISTINCT role_name FROM rec_roles ORDER BY role_name;
$$ LANGUAGE sql STABLE;


