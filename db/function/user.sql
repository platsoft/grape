
/**
 * @input user_id INTEGER
 * @input username TEXT
 * @input password TEXT
 * @input email TEXT
 * @input fullnames TEXT
 * @input active BOOLEAN optional
 * @input role_names TEXT[]
 * @input employee_guid GUID
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

	rec RECORD;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;
	_username := $1->>'username';
	_password := $1->>'password';
	_email := $1->>'email';
	_fullnames := $1->>'fullnames';
	_active := ($1->>'active')::BOOLEAN;

	IF json_typeof ($1->'role_names') = 'string' THEN
		_role_names := string_to_array($1->>'role_names', ',');
	ELSIF json_typeof ($1->'role_names') = 'array' THEN
		_role_names := ($1->'role_names')::TEXT[];
	END IF;

	IF json_extract_path($1, 'employee_guid') IS NOT NULL THEN
		_employee_guid := ($1->>'employee_guid')::UUID;
	END IF;

	IF grape.get_value('passwords_hashed', 'false') = 'true' THEN
		_hashed_password := crypt(_password, gen_salt('bf'));
	ELSE
		_hashed_password := _password;
	END IF;

	-- Validate Username
	IF _username IS NULL OR _username = '' THEN
		RETURN grape.api_error('Invalid data - Username is missing', 1);
	END IF;

	-- Default Active to True
	IF _active IS NULL THEN
		_active := TRUE;
	END IF;

	-- Select appropriate operations
	IF _user_id IS NULL THEN
		-- INSERT New User
		SELECT * INTO rec FROM grape."user" WHERE username = _username::TEXT;
		IF NOT FOUND THEN
			-- INSERT : Valid data
			INSERT INTO grape."user" (username, password, email, fullnames, active, employee_guid)
				VALUES (_username, _hashed_password, _email, _fullnames, _active, _employee_guid)
				RETURNING user_id INTO _user_id;

			IF _role_names IS NOT NULL THEN
				FOREACH _role_name IN ARRAY _role_names LOOP
					INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
				END LOOP;
			END IF;

			RETURN grape.api_success(json_build_object('new', 'true', 'user_id', _user_id));

		ELSE
			-- INSERT : Username taken
			RETURN grape.api_error('Unable to insert user. The username already exists', 2);

		END IF;
	ELSE
		-- UPDATE Existing User
		SELECT * INTO rec FROM grape."user" WHERE user_id = _user_id;
		IF NOT FOUND THEN
			-- UPDATE : Invalid user_id
			RETURN grape.api_error('Unable to update user. The specified user_id does not exist', 3);

		ELSE
			SELECT * INTO rec FROM grape."user" WHERE username = _username;
			IF FOUND AND rec.user_id <> _user_id THEN
				-- UPDATE : Existing username
				RETURN grape.api_error('Unable to update user. The username already exists', 4);

			END IF;

			-- UPDATE : Valid data
			UPDATE grape."user"
				SET
					username = _username,
					password = _hashed_password,
					email = _email,
					fullnames = _fullnames,
					active = _active,
					employee_guid=COALESCE(_employee_guid, employee_guid)
				WHERE
					user_id = _user_id;

			IF _role_names IS NOT NULL THEN
				DELETE FROM grape.user_role WHERE user_id = _user_id::INTEGER;
				FOREACH _role_name IN ARRAY _role_names LOOP
					INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
				END LOOP;
			END IF;

			RETURN grape.api_success(json_build_object('new', 'false', 'user_id', _user_id));
		END IF;
	END IF;
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

	SELECT * INTO rec FROM grape."user" WHERE username = _username::TEXT;
	IF NOT FOUND THEN
		INSERT INTO grape."user" (username, password, active, is_local)
			VALUES (_username, _password, true, true)
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
 * Returns a username for fullnames
 */
CREATE OR REPLACE FUNCTION grape.username_from_fullnames(_fullnames TEXT) RETURNS TEXT AS $$
        SELECT username FROM grape."user" WHERE LOWER(fullnames)=LOWER(_fullnames)::TEXT;
$$ LANGUAGE sql;


/**
 * Hashes a password for user and updates the user table afterwards
 *
 * If the hash length is the same as the password length and the password starts with a '$' sign, it is assumed that the password is already hashed and the update is ignored (return -1)
 * If grape.setting  passwords_hashed isn't true, nothing is done (return -2)
 * On success 0 is returned
 */
CREATE OR REPLACE FUNCTION grape.hash_user_password (_user_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_password TEXT;
	_hashed_password TEXT;
BEGIN

	IF grape.get_value('passwords_hashed', 'false') != 'true' THEN
		RAISE DEBUG 'passwords_hashed in settings is not true';
		RETURN -2;
	END IF;

	SELECT password INTO _password FROM grape."user" WHERE user_id=_user_id::INTEGER;

	_hashed_password := crypt(_password, gen_salt('bf'));

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
	_hashed_locally := grape.get_value('passwords_hashed', 'false')::BOOLEAN;

	IF _hashed_locally = _is_hashed THEN
		_password_to_save := _password;
	ELSIF _hashed_locally = FALSE AND _is_hashed = TRUE THEN
		RAISE NOTICE 'Cannot save a clear-text password from a hash';
		RETURN FALSE;
	ELSIF _hashed_locally = TRUE AND _is_hashed = FALSE THEN
		_password_to_save := crypt(_password, gen_salt('bf'));
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

	_ret := grape.set_user_password(_user_id, _password, _is_hashed);

	IF _ret = FALSE THEN
		RETURN grape.api_error('Could not save password', -1);
	END IF;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.resend_user_password(JSONB) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_user RECORD;
	_sysname TEXT;
	_additional_data JSONB;
	_firstname TEXT;
BEGIN

	IF $1 ? 'user_id' THEN
		_user_id := ($1->>'user_id')::INTEGER;
	END IF;

	IF _user_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	IF $1 ? 'additional_data' THEN
		_additional_data := $1->'additional_data';
	ELSE
		_additional_data := '{}';
	END IF;


	_sysname := grape.get_value('product_name', '');

	SELECT u.*, 
		_sysname AS product_name, 
		grape.get_value('system_url', '') AS url,
		u.employee_info->>'firstname' AS firstname
		
	INTO _user 
	FROM grape."user" u 
	WHERE user_id=_user_id::INTEGER;

	IF _user.firstname IS NULL OR _user.firstname = '' THEN
		_user.firstname := _user.fullnames;
	END IF;

	IF _user.email IS NULL OR _user.email = '' THEN
		RETURN grape.api_error('No email address are saved for this user', -10);
	END IF;	
	
	_additional_data := _additional_data || to_jsonb(_user);

	PERFORM grape.send_email(_user.email::TEXT, 'login_details', _additional_data::JSON);

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
	END IF;

	IF _user_id IS NULL THEN
		RETURN grape.api_invalid_input_error();
	END IF;

	IF grape.current_user_in_role('admin') = FALSE AND _user_id != current_user_id() THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	SELECT to_jsonb(u) INTO _ret FROM grape."user" u WHERE user_id=_user_id::INTEGER;

	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;
	
	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=_user_id::INTEGER;

	_ret := _ret || jsonb_build_object('user_roles', _user_roles);
	
	RETURN grape.api_success('user', _ret::JSON);
END; $$ LANGUAGE plpgsql;



