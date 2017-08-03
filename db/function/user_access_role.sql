
CREATE OR REPLACE FUNCTION grape.add_user_to_access_role(_user_id INTEGER, _access_role TEXT) RETURNS INTEGER AS $$
	INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, _access_role) RETURNING 0;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.add_user_to_access_role(_username TEXT, _access_role TEXT) RETURNS INTEGER AS $$
	INSERT INTO grape.user_role(user_id, role_name) VALUES (grape.user_id_from_name(_username), _access_role) RETURNING 0;
$$ LANGUAGE sql;

