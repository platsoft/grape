
-- Generate the key that will be saved in the DB. this function calls itself until _rounds is 0
CREATE OR REPLACE FUNCTION grape.generate_user_key (_password TEXT, _salt TEXT, _rounds INTEGER) RETURNS TEXT AS $$
DECLARE
	_i INTEGER := _rounds;
	_init TEXT;
BEGIN

	WHILE _i > 0 LOOP
		_init := ENCODE(DIGEST(COALESCE(_init, '') || _salt || _password, 'sha256'), 'hex');
		_i := _i - 1;
	END LOOP;

	RETURN _init;
END; $$ LANGUAGE plpgsql;

-- Generate a string in the format sha256:SALT:HASH to save in the DB. we have to save the salt and hash algo for future reference
CREATE OR REPLACE FUNCTION grape.generate_user_pw_hash(_password TEXT) RETURNS TEXT AS $$
DECLARE
	_salt TEXT;
	_rounds INTEGER;
	_algorithm TEXT;
	_key TEXT;
BEGIN

	_rounds := grape.get_value('password_hashing_rounds', '1000')::INTEGER;
	_algorithm := grape.get_value('password_hashing_algo', 'sha256'); -- we cannot really go over sha256 because AES takes 256 as key input

	_salt := encode(gen_random_bytes(10), 'hex');
	
	_key := grape.generate_user_key(_password, _salt, _rounds);

	
	RETURN CONCAT_WS(':', _algorithm || '-' || _rounds::TEXT, _salt, _key);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.get_user_key_fields(_key TEXT) RETURNS TABLE (algo TEXT, rounds INTEGER, salt TEXT, key TEXT) AS $$
DECLARE
	
BEGIN
	algo := split_part(split_part(_key, ':', 1), '-', 1);
	rounds := (split_part(split_part(_key, ':', 1), '-', 2))::INTEGER;
	salt := split_part(_key, ':', 2);
	key := split_part(_key, ':', 3);
	RETURN NEXT;
END; $$ LANGUAGE plpgsql;


