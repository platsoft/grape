
/**
 * @input user_id INTEGER
 * @input username TEXT
 * @input password TEXT
 * @input email TEXT
 * @input fullnames TEXT
 * @input active BOOLEAN optional
 * @input role_names TEXT[]
 * @input guid GUID
 */
CREATE OR REPLACE FUNCTION grape.user_save (JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_username TEXT;
	_password TEXT;
	_email TEXT;
	_fullnames TEXT;
	_active BOOLEAN;
	_role_names TEXT[];
	_role_name TEXT;
	_hashed_password TEXT;
	_employee_guid UUID;
	_in JSONB := $1::JSON;

	rec RECORD;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;

	IF json_typeof ($1->'role_names') = 'string' THEN
		_role_names := string_to_array($1->>'role_names', ',');
	ELSIF json_typeof ($1->'role_names') = 'array' THEN
		_role_names := ($1->'role_names')::TEXT[];
	END IF;

	IF json_extract_path($1, 'employee_guid') IS NOT NULL THEN
		_employee_guid := ($1->>'employee_guid')::UUID;
	ELSIF json_extract_path($1, 'guid') IS NOT NULL THEN
		_employee_guid := ($1->>'guid')::UUID;
	END IF;

	IF _user_id IS NULL AND grape.current_username() = _in->>'username' THEN
		_user_id := grape.current_user_id();
	END IF;

	IF _user_id IS NULL THEN
		_username := $1->>'username';
		IF _username IS NULL THEN
			RETURN grape.api_error_invalid_field('username');
		END IF;
		
		IF EXISTS (SELECT 1 FROM grape."user" WHERE username=_username::TEXT) THEN	
			RETURN grape.api_error('Unable to insert user. The username already exists', 2);
		END IF;
	
		IF _employee_guid IS NULL THEN
			_employee_guid := grape.generate_uuid(); 
		END IF;

		INSERT INTO grape."user" (username, employee_guid) VALUES (_username, _employee_guid) RETURNING user_id INTO _user_id;

		IF _role_names IS NOT NULL THEN
			FOREACH _role_name IN ARRAY _role_names LOOP
				INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
			END LOOP;
		END IF;


	ELSE
		IF _employee_guid IS NOT NULL THEN
			UPDATE grape."user" SET employee_guid=_employee_guid WHERE user_id=_user_id::INTEGER;
		END IF;
	END IF;
		
	INSERT INTO grape.user_history (user_id, data, blame_id)
		VALUES (_user_id, $1::JSONB, current_user_id());

	IF _in ? 'password' THEN
		_password := $1->>'password';
		IF grape.get_value('hash_passwords', 'false') = 'true' THEN
			_hashed_password := grape.generate_user_pw_hash(_password);
		ELSE
			_hashed_password := _password;
		END IF;
		
		UPDATE grape."user" SET password = _hashed_password WHERE user_id = _user_id::INTEGER;
	END IF;

	IF _in ? 'active' THEN
		_active := ($1->>'active')::BOOLEAN;
		UPDATE grape."user" SET active=_active WHERE user_id=_user_id::INTEGER;
	END IF;
	
	IF _in ? 'email' THEN
		_email := ($1->>'email');
		UPDATE grape."user" SET email=_email WHERE user_id=_user_id::INTEGER;
		PERFORM grape.user_update_auth_info(_user_id, 'email_status', 'unverified');
	END IF;

	IF _in ? 'fullnames' THEN
		_fullnames := ($1->>'fullnames');
		UPDATE grape."user" SET fullnames=_fullnames WHERE user_id=_user_id::INTEGER;
	END IF;

	IF _role_names IS NOT NULL THEN
		DELETE FROM grape.user_role WHERE user_id = _user_id::INTEGER;
		FOREACH _role_name IN ARRAY _role_names LOOP
			INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, TRIM(_role_name));
		END LOOP;
	END IF;

	IF _in ? 'totp_status' THEN
		PERFORM grape.user_update_auth_info(_user_id, 'totp_status', _in->>'totp_status');
	END IF;
	
	IF _in ? 'auth_server' THEN
		PERFORM grape.user_update_auth_info(_user_id, 'auth_server', _in->>'auth_server');
	END IF;
	
	IF _in ? 'auth_server_search_base' THEN
		PERFORM grape.user_update_auth_info(_user_id, 'auth_server_search_base', _in->>'auth_server_search_base');
	END IF;
	
	RETURN grape.api_success(json_build_object('user_id', _user_id));
END; $$ LANGUAGE plpgsql;

/**
 * Create new user 
 */
CREATE OR REPLACE FUNCTION grape.new_user (_username TEXT, _role_names TEXT[], _password TEXT) RETURNS INTEGER AS $$
DECLARE
	_user_id INTEGER;
	_rec RECORD;
	_role_name TEXT;
BEGIN

	SELECT * INTO _rec FROM grape."user" WHERE username = _username::TEXT;
	IF NOT FOUND THEN
		INSERT INTO grape."user" (username, password, active)
			VALUES (_username, _password, true)
			RETURNING user_id INTO _user_id;

		IF _role_names IS NOT NULL THEN
			FOREACH _role_name IN ARRAY _role_names LOOP
				INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
			END LOOP;
		END IF;

		PERFORM grape.hash_user_password(_user_id);

		RETURN _user_id;
	ELSE
		RETURN -1;
	END IF;
END; $$ LANGUAGE plpgsql;

/**
 * Returns a username belonging to a user_id
 */
CREATE OR REPLACE FUNCTION grape.username (_user_id INTEGER) RETURNS TEXT AS $$
	SELECT username FROM grape."user" WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;

/**
 * Returns a user_id for a username
 */
CREATE OR REPLACE FUNCTION grape.user_id_from_name (_username TEXT) RETURNS INTEGER AS $$
	SELECT user_id FROM grape."user" WHERE username=_username::TEXT;
$$ LANGUAGE sql;

/**
 * Returns user_id for fullnames
 */
CREATE OR REPLACE FUNCTION grape.user_id_from_fullnames(_fullnames TEXT) RETURNS INTEGER AS $$
        SELECT user_id FROM grape."user" WHERE fullnames=_fullnames::TEXT;
$$ LANGUAGE sql;

/**
 * Returns user_id from email
 */
CREATE OR REPLACE FUNCTION grape.user_id_from_email(_email TEXT) RETURNS INTEGER AS $$
        SELECT user_id FROM grape."user" WHERE email=_email::TEXT;
$$ LANGUAGE sql;


/**
 * Returns a username for fullnames
 */
CREATE OR REPLACE FUNCTION grape.username_from_fullnames(_fullnames TEXT) RETURNS TEXT AS $$
        SELECT username FROM grape."user" WHERE LOWER(fullnames)=LOWER(_fullnames)::TEXT;
$$ LANGUAGE sql;


/**
 * Hashes a password for user and updates the user table afterwards
 *
 * If the hash length is the same as the password length and the password starts with a '$' sign, it is assumed that the password is already hashed and the update is ignored (return -1)
 * If grape.setting  hash_passwords isn't true, nothing is done (return -2)
 * On success 0 is returned
 */
CREATE OR REPLACE FUNCTION grape.hash_user_password (_user_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_password TEXT;
	_hashed_password TEXT;
BEGIN

	IF grape.get_value('hash_passwords', 'false') != 'true' THEN
		RAISE DEBUG 'hash_passwords in settings is not true';
		RETURN -2;
	END IF;

	SELECT password INTO _password FROM grape."user" WHERE user_id=_user_id::INTEGER;

	_hashed_password := grape.generate_user_pw_hash(_password);

	IF LENGTH(_hashed_password) = LENGTH(_password) AND SUBSTRING(_password, 1, 1) = '$' THEN
		RAISE DEBUG 'Password hashed is the same length as password and it starts with a dollar sign, not updateing it';
		RETURN -1;
	END IF;

	UPDATE grape."user" SET password=_hashed_password WHERE user_id=_user_id::INTEGER;

	RETURN 0;
END; $$ LANGUAGE plpgsql;

/**
 * Overload for grape.hash_user_password (_user_id) taking a username instead of user_id
 */
CREATE OR REPLACE FUNCTION grape.hash_user_password (_username TEXT) RETURNS INTEGER AS $$
DECLARE
	_user_id INTEGER;
BEGIN
	_user_id := grape.user_id_from_name(_username);

	IF _user_id IS NULL THEN
		RAISE DEBUG 'Username % not found', _username;
		RETURN -1;
	END IF;

	RETURN grape.hash_user_password(_user_id);
END; $$ LANGUAGE plpgsql;

/**
 * Set user password 
 * is_hashed should be TRUE if the password given to this function is already hashed
 */
CREATE OR REPLACE FUNCTION grape.set_user_password (_user_id INTEGER, _password TEXT, _is_hashed BOOLEAN) RETURNS BOOLEAN AS $$
DECLARE
	_hashed_locally BOOLEAN;
	_password_to_save TEXT;
BEGIN
	-- do we hash local passwords?
	_hashed_locally := grape.get_value('hash_passwords', 'false')::BOOLEAN;

	IF _hashed_locally = _is_hashed THEN
		_password_to_save := _password;
	ELSIF _hashed_locally = FALSE AND _is_hashed = TRUE THEN
		RAISE NOTICE 'Cannot save a clear-text password from a hash';
		RETURN FALSE;
	ELSIF _hashed_locally = TRUE AND _is_hashed = FALSE THEN
		_password_to_save := grape.generate_user_pw_hash(_password);
		-- TODO save the password for SCRAM-SHA256 perhaps in auth_info
	END IF;

	UPDATE grape."user" SET password=_password_to_save WHERE user_id=_user_id::INTEGER;
	
	RETURN TRUE;
END; $$ LANGUAGE plpgsql;

/**
 * Set user password 
 * is_hashed should be TRUE if the password given to this function is already hashed
 */
CREATE OR REPLACE FUNCTION grape.set_user_password (_username TEXT, _password TEXT, _is_hashed BOOLEAN) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	RETURN grape.set_user_password(grape.user_id_from_name(_username), _password, _is_hashed);
END; $$ LANGUAGE plpgsql;

/**
 * Set user password 
 */
CREATE OR REPLACE FUNCTION grape.set_user_password (JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_username TEXT;
	_is_hashed BOOLEAN;
	_password TEXT;

	_ret BOOLEAN;
BEGIN
	_password := $1->>'password';
	_is_hashed := ($1->>'is_hashed')::BOOLEAN;
	
	IF json_extract_path($1, 'username') IS NOT NULL THEN
		_username := $1->>'username';
		_user_id := grape.user_id_from_name(_username);
	ELSIF json_extract_path($1, 'user_id') IS NOT NULL THEN
		_user_id := ($1->>'user_id')::INTEGER;
	END IF;

	-- TODO check that user is admin or _user_id matchs grape.current_user_id()

	_ret := grape.set_user_password(_user_id, _password, _is_hashed);

	IF _ret = FALSE THEN
		RETURN grape.api_error('Could not save password', -1);
	END IF;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


/**
 * IN: 
 * 	user_id 
 * 	employee_guid
 * 	employee_info 
 */
CREATE OR REPLACE FUNCTION grape.update_user_employee_info(JSONB) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_employee_guid UUID;
	_employee_info JSONB;
BEGIN
	IF $1 ? 'user_id' THEN
		_user_id := ($1->>'user_id')::INTEGER;
	END IF;

	IF $1 ? 'employee_guid' THEN
		_employee_guid := ($1->>'employee_guid');
	ELSIF $1 ? 'guid' THEN
		_employee_guid := ($1->>'guid');
	END IF;

	IF _user_id IS NULL AND _employee_guid IS NOT NULL THEN
		_user_id := (SELECT user_id FROM grape."user" WHERE employee_guid=_employee_guid::UUID);
	END IF;

	IF $1 ? 'employee_info' THEN
		_employee_info := $1->'employee_info';
	END IF;

	IF _user_id IS NULL OR _employee_info IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	UPDATE grape."user" SET 
		employee_info=_employee_info
		WHERE user_id=_user_id::INTEGER;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

/**
 * @apicall:
 * IN: 
 * 	user_id 
 * OUT:
 * 	user
 * 		email
 * 		active
 * 		employee_guid
 * 		user_roles
 */
CREATE OR REPLACE FUNCTION grape.select_user(JSONB) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_user_roles TEXT[];
	_ret JSONB;
BEGIN
	IF $1 ? 'user_id' THEN
		_user_id := ($1->>'user_id')::INTEGER;
		IF _user_id = -1 THEN
			_user_id := grape.current_user_id();
		END IF;
	END IF;

	IF _user_id IS NULL THEN
		RETURN grape.api_invalid_input_error();
	END IF;

	IF grape.current_user_in_role('admin') = FALSE AND _user_id != current_user_id() THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	SELECT to_jsonb(a) INTO _ret FROM (
		SELECT 
			username, 
			email, 
			fullnames, 
			active, 
			employee_guid, 
			employee_info, 
			COALESCE(auth_info->>'totp_status', '') AS totp_status,
			COALESCE(auth_info->>'mobile', '') AS mobile,
			COALESCE(auth_info->>'mobile_status', '') AS mobile_status
		FROM grape."user" WHERE user_id=_user_id::INTEGER
	) a;

	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;
	
	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=_user_id::INTEGER;

	_ret := _ret || jsonb_build_object('user_roles', _user_roles);
	
	RETURN grape.api_success('user', _ret::JSON);
END; $$ LANGUAGE plpgsql;



