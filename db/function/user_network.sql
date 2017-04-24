/*
-- Work in progress 
-- ::/0 'IPv4 all'
-- 0.0.0.0/0  'IPv6 all'
-- 127.0.0.1 'IPv4 localhost'
-- ::1 'IPv6 localhost'

CREATE OR REPLACE FUNCTION grape.user_ip_whitelist_insert (_user_id INTEGER, _address INET) RETURNS INTEGER AS $$
DECLARE
BEGIN
	
	
END; $$ LANGUAGE plpgsql;

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

*/
