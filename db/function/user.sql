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

	rec RECORD;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;
	_username := $1->>'username';
	_password := $1->>'password';
	_email := $1->>'email';
	_fullnames := $1->>'fullnames';
	_active := ($1->>'active')::BOOLEAN;
	_role_names := string_to_array($1->>'role_names', ',');

	IF grape.get_value('passwords_hashed', 'false') = 'true' THEN
		_hashed_password := crypto.crypt(_password, crypto.gen_salt('bf'));
	ELSE
		_hashed_password := _password;
	END IF;

	-- Validate Username
	IF _username IS NULL OR _username = '' THEN
		RETURN ('{"success":"false","code":"1","message":"Invalid data - Username is mandatory."}')::JSON;
	END IF;

	-- Default Active to True
	IF _active IS NULL THEN
		_active := TRUE;
	END IF;

	-- Select appropriate operations
	IF _user_id IS NULL THEN
		-- INSERT New User
		SELECT * INTO rec FROM grape."user" WHERE username = _username;
		IF NOT FOUND THEN
			-- INSERT : Valid data
			INSERT INTO grape."user" (username, password, email, fullnames, active)
				VALUES (_username, _hashed_password, _email, _fullnames, _active)
				RETURNING user_id INTO _user_id;

			IF _role_names IS NOT NULL THEN
				FOREACH _role_name IN ARRAY _role_names LOOP
					INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
				END LOOP;
			END IF;

			RETURN ('{"success":"true","code":"0","new":"true","user_id":"' || _user_id || '"}')::JSON;

		ELSE
			-- INSERT : Username taken
			RETURN ('{"success":"false","code":"2","message":"Unable to insert user. The username already exists"}')::JSON;

		END IF;
	ELSE
		-- UPDATE Existing User
		SELECT * INTO rec FROM grape."user" WHERE user_id = _user_id;
		IF NOT FOUND THEN
			-- UPDATE : Invalid user_id
			RETURN ('{"success":"false","code":"3","message":"Unable to update user. The specified user_id does not exist"}')::JSON;

		ELSE
			SELECT * INTO rec FROM grape."user" WHERE username = _username;
			IF FOUND AND rec.user_id <> _user_id THEN
				-- UPDATE : Existing username
				RETURN ('{"success":"false","code":"4","message":"Unable to update user. The username already exists"}')::JSON;

			END IF;

			-- UPDATE : Valid data
			UPDATE grape."user"
				SET
					username = _username,
					password = _hashed_password,
					email = _email,
					fullnames = _fullnames,
					active = _active
				WHERE
					user_id = _user_id;

			IF _role_names IS NOT NULL THEN
				DELETE FROM grape.user_role WHERE user_id = _user_id::INTEGER;
				FOREACH _role_name IN ARRAY _role_names LOOP
					INSERT INTO grape.user_role(user_id, role_name) VALUES (_user_id, trim(_role_name));
				END LOOP;
			END IF;

			RETURN ('{"success":"true","code":"0","new":"false","user_id":"' || _user_id || '"}')::JSON;

		END IF;
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
        SELECT username FROM grape."user" WHERE fullnames=_fullnames::TEXT;
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



