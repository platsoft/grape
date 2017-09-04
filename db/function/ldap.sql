
CREATE OR REPLACE FUNCTION grape.ldap_check_credentials(_dn TEXT, _credentials TEXT, _ip_address TEXT) RETURNS INTEGER AS $$
DECLARE
	_user RECORD;
BEGIN

	SELECT * INTO _user FROM grape.v_ldap_users WHERE dn=_dn::TEXT; 
	IF NOT FOUND THEN
		RETURN -1; -- no such user  NoSuchObjectError
	END IF;

	IF grape.get_value('user_ip_filter', 'false') = 'true' THEN
		IF grape.check_user_ip (_user.user_id::INTEGER, _ip_address::INET) = 2 THEN
			RAISE NOTICE 'IP filter check failed for user % (IP %)', _user.username, _ip_address;
			RETURN -4; -- InsufficientAccessRightsError
		END IF;
	END IF;

	IF _user.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN -3; -- InsufficientAccessRightsError
	END IF;

	IF grape.check_user_password(_user.password, _credentials) = TRUE THEN
		RETURN 0;
	ELSE
		RETURN -5; -- InvalidCredentialsError
	END IF;

END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.ldap_fetch_all(JSONB) RETURNS JSONB AS $$
DECLARE
	_dn TEXT = $1->>'dn';
	_records JSONB;
BEGIN
	IF _dn = 'o=platsoft,ou=Users' THEN
		SELECT jsonb_agg(a) INTO _records FROM (SELECT * FROM grape.v_ldap_users) a;
	ELSE
		RETURN grape.api_error();
	END IF;

	RETURN grape.api_success('records', _records::JSON);
END; $$ LANGUAGE plpgsql;


