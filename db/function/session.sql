
-- Require: user.sql

/**
 * Input:
 * 	username or email
 * 	password
 *	ip_address
 *	persistant true/false optional Persistant sessions
 *
 * status = ERROR
 * code 1 = No such user
 * code 2 = Wrong password
 * code 3 = User is inactive
 * code 4 = IP not allowed
 *
 * On success: status = OK
 * and following fields: session_id, user_id, username and user_roles
 *
 * Setting hash_passwords is used to decide if passwords are hashed or not
 */
CREATE OR REPLACE FUNCTION grape.session_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user TEXT;
	_password TEXT;
	_email TEXT;
	_ip_address TEXT;

	rec RECORD;

	_session_id TEXT;
	_found BOOLEAN;
	
	_persistant BOOLEAN;

	_user_roles TEXT[];

	_ret JSON;

	_check_password TEXT;
BEGIN

	IF json_extract_path($1, 'username') IS NOT NULL THEN
		_user := $1->>'username';
		SELECT * INTO rec FROM grape."user" WHERE username=_user::TEXT;
	ELSIF json_extract_path($1, 'email') IS NOT NULL THEN
		_email := $1->>'email';
		SELECT * INTO rec FROM grape."user" WHERE email=_email::TEXT;
	ELSE
		RETURN grape.api_error_invalid_input('{"message":"Missing email or username"}');
	END IF;

	IF rec IS NULL THEN
		RAISE DEBUG 'User % % login failed. No such user', _user, _email;
		RETURN grape.api_result_error('No such user', 1);
	END IF;

	IF _user IS NULL THEN
		_user := rec.username;
	END IF;
	
	_password := $1->>'password';
	_ip_address := $1->>'ip_address';

	_persistant := FALSE;

	IF json_extract_path($1, 'persistant') IS NOT NULL THEN
		_persistant := ($1->>'persistant')::BOOLEAN;
	END IF;

	IF grape.get_value('user_ip_filter', 'false') = 'true' THEN
		IF grape.check_user_ip (rec.user_id::INTEGER, _ip_address::INET) = 2 THEN
			RAISE NOTICE 'IP filter check failed for user % (IP %)', _user, _ip_address;
			RETURN grape.api_result_error('IP not allowed', 4);
		END IF;
	END IF;

	IF rec.password IS NULL THEN
		RETURN grape.api_result_error('Your account does not have a valid password', 3);
	END IF;

	IF grape.get_value('disable_passwords', 'false') = 'false' THEN

		IF grape.check_user_password(rec.password, _password) = FALSE THEN
			RAISE DEBUG 'User % login failed. Password does not match', _user;
			RETURN grape.api_result_error('Invalid password', 2);
		END IF;
	END IF;

	IF rec.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	_found := TRUE;

	IF _persistant = TRUE THEN
		SELECT session_id INTO _session_id FROM grape."session" WHERE user_id=rec.user_id::INTEGER;
		IF NOT FOUND THEN
			_session_id := grape.session_insert(rec.user_id::INTEGER, _ip_address);
		END IF;
	ELSE
		_session_id := grape.session_insert(rec.user_id::INTEGER, _ip_address);
	END IF;

	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=rec.user_id::INTEGER;

	SELECT to_json(a) INTO _ret FROM (
		SELECT 'true' AS "success",
			'OK' AS "status",
			0 AS "code",
			_session_id AS "session_id",
			_user AS "username",
			_user_roles AS "user_roles",
			rec.fullnames AS "fullnames",
			rec.email AS "email",
			rec.employee_guid AS "employee_guid"
		) a;

	PERFORM pg_notify('new_session', _ret::TEXT);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.session_insert(_user_id INTEGER, _ip_address TEXT) RETURNS TEXT AS $$
DECLARE
	_found BOOLEAN;
	_session_id TEXT;
BEGIN
	_found := TRUE;

	WHILE _found = TRUE LOOP
		_session_id := CONCAT(_user_id, '-', grape.random_string(15));
		IF
			EXISTS (SELECT session_id FROM grape."session" WHERE session_id=_session_id::TEXT)
			OR EXISTS (SELECT session_id FROM grape."session_history" WHERE session_id=_session_id::TEXT)
		THEN
			_found := TRUE;
		ELSE
			_found := FALSE;
		END IF;
	END LOOP;

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity)
		VALUES (_session_id, _ip_address, _user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

	RETURN _session_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.create_session_from_service_ticket(JSONB) RETURNS JSONB AS $$
DECLARE
	_service_ticket_encrypted TEXT;
	_service_ticket JSONB;
	_user RECORD;
	_persistant BOOLEAN;
	_session_id TEXT;
	_ip_address TEXT;
	_ret JSONB;
BEGIN
	_service_ticket_encrypted := ($1->>'service_ticket');
	_service_ticket := grape.validate_service_ticket(_service_ticket_encrypted);

	IF _service_ticket IS NULL THEN
		RETURN grape.api_error();
	ELSIF _service_ticket->>'status' = 'ERROR' THEN
		RETURN _service_ticket;
	END IF;
	
	SELECT * INTO _user FROM grape."user" WHERE username=_service_ticket->>'username' AND employee_guid=(_service_ticket->>'employee_guid')::UUID; 
	IF NOT FOUND THEN
		RETURN grape.api_error('No such user', -3);
	END IF;

	_ip_address := $1->>'ip_address';
	_persistant := FALSE;

	IF jsonb_extract_path($1, 'persistant') IS NOT NULL THEN
		_persistant := ($1->>'persistant')::BOOLEAN;
	END IF;

	IF grape.get_value('user_ip_filter', 'false') = 'true' THEN
		IF grape.check_user_ip (_user.user_id::INTEGER, _ip_address::INET) = 2 THEN
			RAISE NOTICE 'IP filter check failed for user % (IP %)', _user.username, _ip_address;
			RETURN grape.api_result_error('IP not allowed', 4);
		END IF;
	END IF;

	IF _user.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	IF _persistant = TRUE THEN
		SELECT session_id INTO _session_id FROM grape."session" WHERE user_id=_user.user_id::INTEGER;
		IF NOT FOUND THEN
			_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address);
		END IF;
	ELSE
		_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address);
	END IF;

	
	SELECT jsonb_build_object(
		'success', true,
		'status', 'OK',
		'session_id', _session_id,
		'username', _user.username,
		'user_roles', (SELECT array_agg(role_name) FROM grape."user_role" WHERE user_id=_user.user_id::INTEGER),
		'fullnames', _user.fullnames,
		'email', _user.email,
		'employee_guid', _user.employee_guid
	) INTO _ret;

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

	PERFORM pg_notify('logout', _session_id::TEXT);

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

CREATE OR REPLACE FUNCTION grape.set_session_user_id(_user_id INTEGER) RETURNS TEXT AS $$
	SELECT set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
$$ LANGUAGE sql;

-- Set current session to username
CREATE OR REPLACE FUNCTION grape.set_session_username(_username TEXT) RETURNS TEXT AS $$
	SELECT grape.set_session_user_id(grape.user_id_from_name(_username));
$$ LANGUAGE sql;



CREATE OR REPLACE FUNCTION grape.set_session_user_id(JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;
	PERFORM set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;




