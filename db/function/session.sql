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
	_username TEXT;
	_password TEXT;
	_email TEXT;
	_user RECORD;
BEGIN

	IF json_extract_path($1, 'username') IS NOT NULL THEN
		_username := $1->>'username';
		SELECT * INTO _user FROM grape."user" WHERE username=_username::TEXT;
	ELSIF json_extract_path($1, 'email') IS NOT NULL THEN
		_email := $1->>'email';
		SELECT * INTO _user FROM grape."user" WHERE email=_email::TEXT;
	ELSE
		RETURN grape.api_error_invalid_input('{"message":"Missing email or username"}');
	END IF;

	IF _user IS NULL THEN
		RAISE DEBUG 'User % % login failed. No such user', _username, _email;
		RETURN grape.api_result_error('No such user', 1);
	END IF;

	_password := $1->>'password';

	IF _user.password IS NULL THEN
		RETURN grape.api_result_error('Your account does not have a valid password', 3);
	END IF;

	IF grape.get_value('disable_passwords', 'false') = 'false' THEN
		IF grape.check_user_password(rec.password, _password) = FALSE THEN
			RAISE DEBUG 'User % login failed. Password does not match', _username;
			RETURN grape.api_result_error('Invalid password', 2);
		END IF;
	END IF;

	RETURN grape.create_session_without_login($1::JSONB);
END; $$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS grape.session_insert(INTEGER, TEXT);
CREATE OR REPLACE FUNCTION grape.session_insert(_user_id INTEGER, _ip_address TEXT, _headers JSONB DEFAULT '{}') RETURNS TEXT AS $$
DECLARE
	_session_id TEXT;
	_user RECORD;
BEGIN
	_session_id := CONCAT(grape.random_string(5), EXTRACT('epoch' FROM NOW())::TEXT, grape.random_string(8));

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity, headers)
		VALUES (_session_id, _ip_address, _user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, _headers);

	RETURN _session_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.create_session_without_login(JSONB) RETURNS JSONB AS $$
DECLARE
	_email TEXT;
	_username TEXT;
	_user RECORD;
	_headers JSONB;
	_ip_address TEXT;
	_persistant BOOLEAN;
	_found BOOLEAN;
	_session_id TEXT;
	_ret JSONB;
BEGIN
	IF jsonb_extract_path($1, 'username') IS NOT NULL THEN
		_username := $1->>'username';
		SELECT * INTO _user FROM grape."user" WHERE username=_username::TEXT;
	ELSIF jsonb_extract_path($1, 'email') IS NOT NULL THEN
		_email := $1->>'email';
		SELECT * INTO _user FROM grape."user" WHERE email=_email::TEXT;
	ELSE
		RETURN grape.api_error_invalid_input('{"message":"Missing email or username"}');
	END IF;

	IF _user IS NULL THEN
		RAISE DEBUG 'User % % login failed. No such user', _user, _email;
		RETURN grape.api_result_error('No such user', 1);
	END IF;

	IF _username IS NULL THEN
		_username := _user.username;
	END IF;

	_ip_address := $1->>'ip_address';

	IF json_extract_path($1, 'http_headers') IS NOT NULL THEN
		_headers := ($1->'http_headers')::JSONB;
	END IF;

	_persistant := FALSE;

	IF json_extract_path($1, 'persistant') IS NOT NULL THEN
		_persistant := ($1->>'persistant')::BOOLEAN;
	END IF;

	IF grape.get_value('user_ip_filter', 'false') = 'true' THEN
		IF grape.check_user_ip (_user.user_id::INTEGER, _ip_address::INET) = 2 THEN
			RAISE NOTICE 'IP filter check failed for user % (IP %)', _username, _ip_address;
			RETURN grape.api_result_error('IP not allowed', 4);
		END IF;
	END IF;

	IF _user.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _username;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	_found := TRUE;

	_headers := COALESCE($1->'headers', '[]'::JSONB);

	IF _persistant = TRUE THEN
		SELECT session_id INTO _session_id FROM grape."session" WHERE user_id=_user.user_id::INTEGER;
		IF NOT FOUND THEN
			_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address, _headers);
		END IF;
	ELSE
		_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address, _headers);
	END IF;

	_ret := jsonb_build_object('status', 'OK') || grape.build_session_information(_session_id);

	PERFORM pg_notify('new_session', _ret::TEXT);

	RETURN _ret;
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
	_headers JSONB;
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
			_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address, _headers);
		END IF;
	ELSE
		_session_id := grape.session_insert(_user.user_id::INTEGER, _ip_address, _headers);
	END IF;

	_ret := jsonb_build_object('status', 'OK') || grape.build_session_information(_session_id);

	PERFORM pg_notify('new_session', _ret::TEXT);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.build_session_information(_session_id TEXT) RETURNS JSONB AS $$
	SELECT jsonb_build_object(
		'session_id', _session_id,
		'username', u.username,
		'user_roles', (SELECT array_agg(role_name) FROM grape."user_role" WHERE user_id=u.user_id::INTEGER),
		'fullnames', u.fullnames,
		'email', u.email,
		'employee_guid', u.employee_guid,
		'employee_info', u.employee_info
	) FROM grape.session s JOIN grape."user" u  USING (user_id)
	WHERE session_id=_session_id::TEXT;
$$ LANGUAGE sql;


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
	_sess_info JSONB;
BEGIN
	_session_id := grape.current_session_id();

	_sess_info := grape.build_session_information(_session_id);

	IF _sess_info IS NULL THEN
		RETURN grape.api_result_error('No such session', -3);
	ELSE
		RETURN grape.api_success(grape.build_session_information(_session_id));
	END IF;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.set_session_user_id(_user_id INTEGER) RETURNS TEXT AS $$
	SELECT set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
$$ LANGUAGE sql;

-- Set current session to username
CREATE OR REPLACE FUNCTION grape.set_session_username(_username TEXT) RETURNS TEXT AS $$
	SELECT set_config('grape.username'::TEXT, _username::TEXT, false);
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

CREATE OR REPLACE FUNCTION grape.set_session(_session_id TEXT) RETURNS VOID AS $$
DECLARE
	_ip_address TEXT;
	_user_id INTEGER;
	_username TEXT;
BEGIN
	SELECT
		ip_address,
		user_id,
		grape.username(user_id) AS username
	INTO
		_ip_address,
		_user_id,
		_username
	FROM grape.session
	WHERE session_id=_session_id::TEXT;

	PERFORM set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
	PERFORM set_config('grape.username'::TEXT, _username::TEXT, false);
	PERFORM set_config('grape.ip_address'::TEXT, _ip_address::TEXT, false);
	PERFORM set_config('grape.session_id'::TEXT, _session_id::TEXT, false);

	RETURN ;
END; $$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.set_session(JSON) RETURNS JSON AS $$
DECLARE
	_session_id TEXT;
BEGIN
	_session_id := ($1->>'session_id');
	PERFORM grape.set_session(_session_id);
	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;
