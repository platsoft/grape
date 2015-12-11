

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

	_hashed_password := crypto.crypt(_password, crypto.gen_salt('bf'));

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

CREATE OR REPLACE FUNCTION grape.username (_user_id INTEGER) RETURNS TEXT AS $$
	SELECT username FROM grape."user" WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.user_id_from_name (_username TEXT) RETURNS INTEGER AS $$
	SELECT user_id FROM grape."user" WHERE username=_username::TEXT;
$$ LANGUAGE sql;


