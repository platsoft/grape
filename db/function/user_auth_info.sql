

CREATE OR REPLACE FUNCTION grape.user_update_auth_info(_user_id INTEGER, _field TEXT, _value TEXT) RETURNS VOID AS $$
	UPDATE grape."user" SET auth_info = COALESCE(auth_info, '{}'::JSONB) || jsonb_build_object(_field, _value) WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.get_user_auth_server_info (JSONB) RETURNS JSONB AS $$
DECLARE
	_user_id INTEGER;
	_auth_server TEXT;
	_auth_server_secret TEXT;
BEGIN
	IF $1 ? 'email' THEN
		_user_id := grape.user_id_from_email($1->>'email');
	ELSIF $1 ? 'username' THEN
		_user_id := grape.user_id_from_name($1->>'username');
	END IF;

	IF _user_id IS NULL THEN
		RETURN grape.api_error_data_not_found(json_build_object('message', 'User not found'));
	END IF;

	SELECT auth_info->>'auth_server' INTO _auth_server FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF _auth_server IS NOT NULL THEN
		_auth_server_secret := grape.get_service_shared_key(_auth_server, 'LDAP_AUTH');
	ELSE
		_auth_server := 'local';
		_auth_server_secret := '';
	END IF;

	RETURN jsonb_build_object(
		'status', 'OK', 
		'auth_server', _auth_server, 
		'auth_server_secret', _auth_server_secret
	);
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.get_user_auth_info (_user_id INTEGER) RETURNS TABLE (
	auth_server TEXT, 
	totp_status TEXT,
	mobile_status TEXT
) AS $$
	SELECT 
		COALESCE(auth_info->>'totp_status', ''),
		COALESCE(auth_info->>'auth_server', ''),
		COALESCE(auth_info->>'mobile_status', '')
	FROM 
		grape."user" u
		WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.get_user_auth_info (JSONB) RETURNS JSONB AS $$
DECLARE
	_auth_info JSONB;
	_user_id INTEGER;
BEGIN
	IF $1 ? 'email' THEN
		_user_id := grape.user_id_from_email($1->>'email');
	ELSIF $1 ? 'username' THEN
		_user_id := grape.user_id_from_name($1->>'username');
	END IF;

	IF _user_id IS NULL THEN
		RETURN grape.api_error_data_not_found(json_build_object('message', 'User not found'));
	END IF;

	_auth_info := to_jsonb(grape.get_user_auth_info(_user_id));

	RETURN jsonb_build_object('status', 'OK', 'auth_info', _auth_info);
END; $$ LANGUAGE plpgsql;


