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
 * Setting passwords_hashed is used to decide if passwords are hashed or not
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

	IF grape.get_value('disable_passwords', 'false') = 'false' THEN

		IF grape.get_value('passwords_hashed', 'false') = 'true' THEN
			_password := crypt(_password, rec.password);
			_check_password := rec.password;
		ELSE
			_check_password := rec.password;
		END IF;

		IF _check_password != _password THEN
			RAISE DEBUG 'User % login failed. Password does not match', _user;
			RETURN grape.api_result_error('Invalid password', 2);
		END IF;
	END IF;

	IF rec.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	-- generate unique session id
	_found = TRUE;
	WHILE _found = TRUE LOOP
		_session_id := grape.random_string(15);
		IF
			EXISTS (SELECT session_id FROM grape."session" WHERE session_id=_session_id::TEXT)
			OR EXISTS (SELECT session_id FROM grape."session_history" WHERE session_id=_session_id::TEXT)
		THEN
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
			_user_roles AS "user_roles",
			rec.fullnames AS "fullnames",
			rec.email AS "email",
			rec.employee_guid AS "employee_guid"
		) a;

	PERFORM pg_notify('new_session', _ret::TEXT);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.logout (JSON) RETURNS JSON AS $$
DECLARE
	_session_id TEXT;
	_rec RECORD;
BEGIN
	_session_id := $1->>'session_id';

	SELECT * INTO _rec FROM grape."session" WHERE session_id=_session_id::TEXT;

	IF NOT FOUND THEN
		RETURN grape.api_error('Invalid session', -2);
	END IF;

	INSERT INTO grape.session_history (session_id, ip_address, user_id, date_inserted, last_activity, date_logout)
		VALUES (_rec.session_id, _rec.ip_address, _rec.user_id, _rec.date_inserted, _rec.last_activity, CURRENT_TIMESTAMP);

	DELETE FROM grape."session" WHERE session_id=_session_id::TEXT;

	NOTIFY 'logout', _session_id::TEXT;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.session_ping(JSON) RETURNS JSON AS $$
DECLARE
	_session_id TEXT;
	_rec RECORD;
BEGIN
	_session_id := $1->>'session_id';

	SELECT s.session_id, u.username, s.user_id, u.fullnames, u.email, u.employee_guid, NULL::TEXT[] AS "user_roles" INTO _rec FROM
		grape."session" s
		JOIN grape."user" u USING (user_id)
		WHERE s.session_id=_session_id::TEXT;

	IF NOT FOUND THEN
		RETURN grape.api_error('Invalid session', -2);
	END IF;

	SELECT array_agg(role_name) INTO _rec.user_roles FROM grape."user_role" WHERE user_id=_rec.user_id::INTEGER;

	RETURN grape.api_success(to_json(_rec));
END; $$ LANGUAGE plpgsql;
