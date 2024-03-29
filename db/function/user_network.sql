
-- Work in progress 
-- ::/0 'IPv4 all'
-- 0.0.0.0/0  'IPv6 all'
-- 127.0.0.1 'IPv4 localhost'
-- ::1 'IPv6 localhost'

/**
 * checks _ip_address against all of the user's networks
 * returns 0 if no networks found for this user
 * returns 1 if networks found and matched
 * returns 2 if networks found but ip not matched in any of them
 */
CREATE OR REPLACE FUNCTION grape.check_user_ip (_user_id INTEGER, _ip_address INET) RETURNS INTEGER AS $$
DECLARE
	_network INET;
	_network_count INTEGER;
BEGIN
	_network_count := 0;

	FOR _network IN 
		SELECT address FROM grape.user_network un 
			JOIN grape.network n USING (network_id)
			WHERE un.user_id=_user_id::INTEGER
	LOOP
		_network_count := _network_count + 1;
		IF _network >>= _ip_address THEN
			RETURN 1;
		END IF;
	END LOOP;

	IF _network_count > 0 THEN
		RETURN 2;
	END IF;

	RETURN 0;
END; $$ LANGUAGE plpgsql;

/**
 * Add new whitelist entry for user_id for _address
 */
CREATE OR REPLACE FUNCTION grape.user_ip_whitelist_insert (_user_id INTEGER, _address INET) RETURNS INTEGER AS $$
DECLARE
	_network_id INTEGER;
	_user_network_id INTEGER;
BEGIN
	_network_id := grape.find_network_id(_address);
	IF _network_id IS NULL THEN
		_network_id := grape.network_insert (_address::TEXT, _address::INET);
	END IF;

	RETURN grape.user_ip_whitelist_insert (_user_id, _network_id);
END; $$ LANGUAGE plpgsql;

/**
 * Add new whitelist entry for user and network_id
 */
CREATE OR REPLACE FUNCTION grape.user_ip_whitelist_insert (_user_id INTEGER, _network_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_user_network_id INTEGER;
BEGIN

	_user_network_id := (SELECT user_network_id FROM grape.user_network WHERE user_id=_user_id::INTEGER AND network_id=_network_id::INTEGER);
	
	IF _user_network_id IS NULL THEN
		INSERT INTO grape.user_network (user_id, network_id)
			VALUES (_user_id, _network_id)
			RETURNING user_network_id INTO _user_network_id;
	END IF;
		
	RETURN _user_network_id;
END; $$ LANGUAGE plpgsql;


/**
 * Insert new network
 */
CREATE OR REPLACE FUNCTION grape.network_insert (_description TEXT, _address INET) RETURNS INTEGER AS $$
DECLARE
	_network_id INTEGER;
BEGIN
	_network_id := grape.find_network_id(_description);

	IF _network_id IS NULL THEN
		INSERT INTO grape.network (description, address) 
			VALUES (_description, _address);
	ELSE
		UPDATE grape.network SET address=_address WHERE network_id=_network_id::INTEGER;
	END IF;

	RETURN _network_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.find_network_id(_description TEXT) RETURNS INTEGER AS $$
	SELECT network_id FROM grape.network WHERE description=_description::TEXT;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.find_network_id(_address INET) RETURNS INTEGER AS $$
	SELECT network_id FROM grape.network WHERE address=_address::INET;
$$ LANGUAGE sql;


/** API calls */

CREATE OR REPLACE FUNCTION grape.user_ip_whitelist_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_network_id INTEGER;

	_input JSONB;
BEGIN
	_input := $1::JSONB;

	IF _input ? 'user_id' THEN
		_user_id := (_input->>'user_id')::INTEGER;
	ELSE
		RETURN grape.api_error_invalid_field('user_id');
	END IF;

	IF _input ? 'network_id' THEN
		_network_id := (_input->>'network_id')::INTEGER;
	ELSIF _input ? 'network_description' THEN
		_network_id := grape.find_network_id((_input->>'network_description')::TEXT);
	ELSIF _input ? 'network_address' THEN
		_network_id := grape.find_network_id((_input->>'network_address')::INET);
	ELSE
		RETURN grape.api_error_invalid_field('network_id');
	END IF;

	RETURN grape.api_success('user_network_id', grape.user_ip_whitelist_insert(_user_id, _network_id));
END; $$ LANGUAGE plpgsql;


