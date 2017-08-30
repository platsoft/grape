
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
		'username', _user.username,
		'employee_guid', _user.employee_guid,
		'issued_at', NOW(),
		'session_key', _session_key
	);
	

	RETURN _tgt;
END; $$ LANGUAGE plpgsql;

-- Response codes:
--  0  valid
-- -1  invalid user data
-- -2  expired
CREATE OR REPLACE FUNCTION grape.validate_TGT(JSONB) RETURNS INTEGER AS $$
DECLARE
BEGIN


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
			RETURN grape.api_error('Invalid input', -2);
		END IF;
	ELSIF $1 ? 'email' THEN
		SELECT * INTO _user FROM grape."user" WHERE email=($1->>'email');
		IF NOT FOUND THEN
			RETURN grape.api_error('Invalid input', -2);
		END IF;
	END IF;

	_server_private_key := ENCODE(DIGEST('my private key', 'sha256'), 'hex');

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


CREATE OR REPLACE FUNCTION grape.create_and_wrap_TGT(_user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_user RECORD;
BEGIN
	SELECT * INTO _user FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;
	
	

	RETURN '';
END; $$ LANGUAGE plpgsql;

-- Receives a packet with TGT
CREATE OR REPLACE FUNCTION grape.validate_authenticator() RETURNS INTEGER AS $$
DECLARE
BEGIN


END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.create_service_ticket(_service TEXT, _user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_service_ticket JSONB;
	_user RECORD;
	_start TIMESTAMPTZ;
BEGIN
	SELECT * INTO _user FROM grape."user" WHERE user_id=_user_id::INTEGER;

	_service_ticket := jsonb_build_object(
		'username', _user.username,
		'employee_guid', _user.employee_guid,
		'issued_at', NOW(),
		'valid_until', (NOW() + INTERVAL '8 hours')
	);

	RETURN _service_ticket::TEXT;
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



