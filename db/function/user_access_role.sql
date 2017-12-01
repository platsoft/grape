
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

CREATE OR REPLACE FUNCTION grape.is_user_in_role(_user_id INTEGER, _access_role TEXT) RETURNS BOOLEAN AS $$
	SELECT EXISTS (SELECT 1 FROM grape.user_role WHERE user_id=_user_id::INTEGER AND role_name=_access_role::TEXT);
$$ LANGUAGE sql STABLE;

