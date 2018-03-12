
CREATE OR REPLACE FUNCTION grape.add_user_to_access_role(_user_id INTEGER, _access_role TEXT) RETURNS INTEGER AS $$
	SELECT grape.add_access_role(_access_role);
	INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, _access_role) 
		ON CONFLICT (user_id, role_name) DO NOTHING
		RETURNING 0;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.add_user_to_access_role(_username TEXT, _access_role TEXT) RETURNS INTEGER AS $$
	SELECT grape.add_access_role(_access_role);
	INSERT INTO grape.user_role(user_id, role_name) VALUES (grape.user_id_from_name(_username), _access_role) 
		ON CONFLICT (user_id, role_name) DO NOTHING
		RETURNING 0;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.remove_user_from_access_role(_username TEXT, _access_role TEXT) RETURNS INTEGER AS $$
	DELETE FROM grape.user_role WHERE user_id=grape.user_id_from_name(_username) AND role_name=_access_role::TEXT RETURNING 1;
$$ LANGUAGE sql;


CREATE OR REPLACE FUNCTION grape.get_user_roles(_user_id INTEGER) RETURNS SETOF TEXT AS $$
	WITH RECURSIVE rec_user_roles(role_name) AS (
		SELECT role_name FROM grape.user_role WHERE user_id=_user_id::INTEGER
			UNION ALL
		SELECT parent_role_name FROM 
			grape.access_role_role arr, 
			rec_user_roles rur 
			WHERE arr.child_role_name=rur.role_name
	)
	SELECT DISTINCT role_name FROM rec_user_roles ORDER BY role_name;
$$ LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION grape.is_user_in_role(_user_id INTEGER, _access_role TEXT) RETURNS BOOLEAN AS $$
	SELECT EXISTS (SELECT 1 FROM grape.user_role WHERE user_id=_user_id::INTEGER AND role_name=_access_role::TEXT);
$$ LANGUAGE sql STABLE;

