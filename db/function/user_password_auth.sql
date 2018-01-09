

CREATE OR REPLACE FUNCTION grape.check_user_password(_password_in_db TEXT, _password_given TEXT) RETURNS BOOLEAN AS $$
DECLARE
	_rec RECORD;
	_check TEXT;
BEGIN
	IF LEFT(_password_in_db, 4) = '$2a$' THEN
		IF crypt(_password_given, _password_in_db) = _password_in_db THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;
	ELSIF LEFT(_password_in_db, 6) = 'sha256' THEN
		SELECT * INTO _rec FROM grape.get_user_key_fields(_password_in_db);
		_check := grape.generate_user_key(_password_given, _rec.salt, _rec.rounds);
		IF _check = _rec.key THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;
	ELSE
		IF _password_in_db = _password_given THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;
	END IF;
END; $$ LANGUAGE plpgsql;

/*
CREATE OR REPLACE FUNCTION grape.check_user_digest_access_authentication(_password_in_db TEXT, ) RETURNS BOOLEAN AS $$
DECLARE
	
BEGIN



END; $$ LANGUAGE plpgsql;
*/

