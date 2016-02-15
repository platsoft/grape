

/**
 * Given username, password and ip_address
 * 
 * status = ERROR 
 * code 1 = No such user
 * code 2 = Wrong password
 * code 3 = User is inactive
 *
 * On success: status = OK
 * and following fields: session_id, user_id, username and user_roles
 * 
 */
CREATE OR REPLACE FUNCTION grape.session_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user TEXT;
	_password TEXT;
	_ip_address TEXT;

	rec RECORD;

	_session_id TEXT;
	_found BOOLEAN;

	_user_roles TEXT[];

	_ret JSON;

	_check_password TEXT;
BEGIN
	_user := $1->>'username';
	_password := $1->>'password';
	_ip_address := $1->>'ip_address';

	SELECT * INTO rec FROM grape."user" WHERE username=_user::TEXT;
	IF NOT FOUND THEN
		RAISE DEBUG 'User % login failed. No such user', _user;
		RETURN grape.api_result_error('No such user', 1);
	END IF;

	IF grape.get_value('passwords_hashed', 'false') = 'true' THEN
		_check_password := crypt(_password, rec.password);
	ELSE
		_check_password := rec.password;
	END IF;

	IF _check_password != rec.password THEN
		RAISE DEBUG 'User % login failed. Password does not match', _user;
		RETURN grape.api_result_error('Invalid password', 2);
	END IF;

	IF rec.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	-- generate unique session id
	_found = TRUE;
	WHILE _found = TRUE LOOP
		_session_id := grape.random_string(15);
		IF EXISTS (SELECT session_id FROM grape."session" WHERE session_id=_session_id::TEXT) THEN
			_found := TRUE;
		ELSE
			_found := FALSE;
		END IF;
	END LOOP;

	RAISE DEBUG 'User % logged in successfuly from %. Session ID is now %', _user, _ip_address, _session_id;

	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=rec.user_id::INTEGER;

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity)
		VALUES (_session_id, _ip_address, rec.user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

	SELECT to_json(a) INTO _ret FROM (
		SELECT 'true' AS "success",
			'OK' AS "status",
			0 AS "code",
			_session_id AS "session_id",
			rec.user_id AS "user_id",
			_user AS "username",
			_user_roles AS "user_roles"
		) a;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.logout (JSON) RETURNS JSON AS $$
DECLARE
	_session_id TEXT;
BEGIN
	_session_id := $1->>'session_id';
	DELETE FROM grape."session" WHERE session_id=_session_id::TEXT;
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

