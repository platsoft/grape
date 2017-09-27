
DROP FUNCTION IF EXISTS grape.create_tgt(integer) ;
CREATE OR REPLACE FUNCTION grape.create_TGT(_user_id INTEGER) RETURNS JSONB AS $$
DECLARE
	_user RECORD;
	_tgt JSONB;
	_session_key TEXT;
BEGIN
	SELECT * INTO _user FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;

	
	_session_key := ENCODE(gen_random_bytes(16), 'hex');

	_tgt := jsonb_build_object(
		'status', 'OK',
		'username', _user.username,
		'employee_guid', _user.employee_guid,
		'issued_at', NOW(),
		'valid_until', (NOW() + INTERVAL '8 hours'),
		'issued_by', grape.get_value('service_name', ''),
		'session_key', _session_key
	);
	

	RETURN _tgt;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.TGT_request(JSONB) RETURNS JSONB AS $$
DECLARE
	_ret JSONB;
	_salt TEXT;
	_iv TEXT;
	_username TEXT;
	_email TEXT;
	_tgt JSONB;
	_encrypted_tgt TEXT;
	
	_user_key RECORD;
	_server_private_key TEXT;

	_user RECORD;

	_message JSONB;
	_encrypted_message TEXT;
BEGIN
	
	IF $1 ? 'username' THEN
		SELECT * INTO _user FROM grape."user" WHERE username=($1->>'username');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;

	ELSIF $1 ? 'email' THEN
		SELECT * INTO _user FROM grape."user" WHERE email=($1->>'email');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;
	END IF;

	IF _user.active = FALSE THEN
		RETURN grape.api_error('User is not active', -3);
	END IF;
	
	IF _user.employee_guid IS NULL THEN
		RETURN grape.api_error('You username on the authentication service does not have a valid employee GUID. Please ask your system administrator to complete the configuration for your account', -98);
	END IF;

	_server_private_key := ENCODE(DIGEST(grape.get_server_private_key('TGT'), 'sha256'), 'hex');

	_tgt := grape.create_TGT(_user.user_id);
	_encrypted_tgt := grape.encrypt_message(_tgt::TEXT, _server_private_key, 'c5067fe37e0b025da44ec7578502c7e4');

	_message := jsonb_build_object(
		'tgt', _encrypted_tgt,
		'session_key', _tgt->>'session_key'
	);

	SELECT * INTO _user_key FROM grape.get_user_key_fields(_user.password);

	_iv := ENCODE(gen_random_bytes(16), 'hex');
	_encrypted_message := grape.encrypt_message(_message::TEXT, _user_key.key, _iv);

	_ret := jsonb_build_object(
		'status', 'OK',
		'data', _encrypted_message,
		'salt', _user_key.salt, 
		'iv', _iv,
		'rounds', _user_key.rounds,
		'algo', _user_key.algo
		);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;



/**
 * Grants a service ticket based on TGT
 */
CREATE OR REPLACE FUNCTION grape.service_ticket_request(JSONB) RETURNS JSONB AS $$
DECLARE
	_raw_tgt TEXT;
	_server_private_key TEXT;
	_requested_service TEXT;
	_encrypted_authenticator TEXT;
	_iv TEXT;
	_salt TEXT;
	_authenticator JSONB;
	_decryption_key TEXT;
	_tgt JSONB;
	_user RECORD;

	_service_ticket TEXT;
BEGIN
	
	_raw_tgt := ($1->>'tgt');

	_server_private_key := ENCODE(DIGEST(grape.get_server_private_key('TGT'), 'sha256'), 'hex');
	_tgt := (grape.decrypt_message(_raw_tgt, _server_private_key, 'c5067fe37e0b025da44ec7578502c7e4'))::JSONB;

	-- RAISE NOTICE 'TGT: %', _tgt;

	_requested_service := ($1->>'requested_service');

	IF grape.is_valid_service(_requested_service) = FALSE AND grape.get_value('service_name', '') != _requested_service THEN
		RETURN grape.api_error('No such service: ' + _requested_service);
	END IF;

	_encrypted_authenticator := ($1->>'authenticator');
	_iv := ($1->>'iv');
	_salt := ($1->>'salt');

	_decryption_key := grape.generate_user_key(_tgt->>'session_key', _salt, 1000);

	_authenticator := (grape.decrypt_message(_encrypted_authenticator, _decryption_key, _iv))::JSONB;

	-- RAISE NOTICE 'Authenticator: %', _authenticator;

	IF _authenticator ? 'username' THEN
		SELECT * INTO _user FROM grape."user" WHERE username=(_authenticator->>'username');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;
	ELSIF _authenticator ? 'email' THEN
		SELECT * INTO _user FROM grape."user" WHERE email=(_authenticator->>'email');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;
	END IF;

	IF _user.username != _tgt->>'username' THEN
		RETURN grape.api_error('Non-match on username');
	END IF;

	IF _user.employee_guid != (_tgt->>'employee_guid')::UUID THEN
		RETURN grape.api_error('Non-match on employee GUID');
	END IF;

	-- Time checks
	IF (_tgt->>'valid_until')::TIMESTAMPTZ < NOW() THEN
		RETURN grape.api_error('TGT Expired');
	END IF;

	IF (_authenticator->>'issued_at')::TIMESTAMPTZ < (_tgt->>'issued_at')::TIMESTAMPTZ THEN
		RETURN grape.api_error('Non-match on username');
	END IF;

	_service_ticket := grape.create_service_ticket(_requested_service, _user.user_id);
	_service_ticket := grape.encrypt_message_for_service(_requested_service, _service_ticket);

	RETURN grape.api_success(json_build_object('service_ticket', _service_ticket));
END; $$ LANGUAGE plpgsql;


/**
 * Encrypts any request params sent based on ticket
 */
CREATE OR REPLACE FUNCTION grape.service_ticket_request_generic(JSONB) RETURNS JSONB AS $$
DECLARE
	_raw_tgt TEXT;
	_server_private_key TEXT;
	_requested_service TEXT;
	_encrypted_authenticator TEXT;
	_iv TEXT;
	_salt TEXT;
	_authenticator JSONB;
	_decryption_key TEXT;
	_tgt JSONB;
	_user RECORD;

	_service_ticket TEXT;
BEGIN
	
	_raw_tgt := ($1->>'tgt');
	_server_private_key := ENCODE(DIGEST(grape.get_server_private_key('TGT'), 'sha256'), 'hex');
	_tgt := (grape.decrypt_message(_raw_tgt, _server_private_key, 'c5067fe37e0b025da44ec7578502c7e4'))::JSONB;
	_requested_service := ($1->>'requested_service');

	IF grape.is_valid_service(_requested_service) = FALSE AND grape.get_value('service_name', '') != _requested_service THEN
		RETURN grape.api_error('No such service: ' + _requested_service);
	END IF;

	_encrypted_authenticator := ($1->>'authenticator');
	_iv := ($1->>'iv');
	_salt := ($1->>'salt');
	_decryption_key := grape.generate_user_key(_tgt->>'session_key', _salt, 1000);
	_authenticator := (grape.decrypt_message(_encrypted_authenticator, _decryption_key, _iv))::JSONB;

	IF _authenticator ? 'username' THEN
		SELECT * INTO _user FROM grape."user" WHERE username=(_authenticator->>'username');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;
	ELSIF _authenticator ? 'email' THEN
		SELECT * INTO _user FROM grape."user" WHERE email=(_authenticator->>'email');
		IF NOT FOUND THEN
			RETURN grape.api_error('No such user', -2);
		END IF;
	END IF;

	IF _user.username != _tgt->>'username' THEN
		RETURN grape.api_error('Non-match on username');
	END IF;

	IF _user.employee_guid != (_tgt->>'employee_guid')::UUID THEN
		RETURN grape.api_error('Non-match on employee GUID');
	END IF;

	IF (_tgt->>'valid_until')::TIMESTAMPTZ < NOW() THEN
		RETURN grape.api_error('TGT Expired');
	END IF;

	IF (_authenticator->>'issued_at')::TIMESTAMPTZ < (_tgt->>'issued_at')::TIMESTAMPTZ THEN
		RETURN grape.api_error('Non-match on username');
	END IF;

	_service_ticket := grape.create_service_ticket_generic(_requested_service, _user.user_id, _authenticator);
	_service_ticket := grape.encrypt_message_for_service(_requested_service, _service_ticket);

	RETURN grape.api_success(json_build_object('service_ticket', _service_ticket));
END; $$ LANGUAGE plpgsql;


-- c5067fe37e0b025da44ec7578502c7e4
CREATE OR REPLACE FUNCTION grape.encrypt_message(_data TEXT, _key TEXT, _iv TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	RETURN ENCODE(ENCRYPT_IV(_data::bytea, decode(_key, 'hex'), decode(_iv, 'hex'), 'aes-cbc/pad:pkcs'), 'hex');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.decrypt_message(_data TEXT, _key TEXT, _iv TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	RETURN CONVERT_FROM(DECRYPT_IV(DECODE(_data, 'hex'), decode(_key, 'hex'), decode(_iv, 'hex'), 'aes-cbc/pad:pkcs'), 'utf8');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.get_server_private_key(_role TEXT) RETURNS TEXT AS $$
DECLARE
	_s TEXT;
BEGIN
	SELECT my_secret INTO _s FROM grape.system_private WHERE role=_role::TEXT;
	IF NOT FOUND THEN
		_s := ENCODE(gen_random_bytes(32), 'hex');
		INSERT INTO grape.system_private (my_secret, role, last_reset)
			VALUES (_s, _role, CURRENT_TIMESTAMP);
	END IF;
	RETURN _s;
END; $$ LANGUAGE plpgsql;


