
CREATE OR REPLACE FUNCTION grape.is_valid_service(_name TEXT) RETURNS BOOLEAN AS $$
	SELECT COALESCE((SELECT TRUE FROM grape.service WHERE service_name=_name::TEXT) , FALSE);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.save_service(_service_name TEXT, _shared_secret TEXT) RETURNS INTEGER AS $$
DECLARE
	_service_id INTEGER;
BEGIN
	IF grape.is_valid_service(_service_name) = TRUE THEN
		UPDATE grape.service SET shared_secret=_shared_secret WHERE service_name=_service_name::TEXT;
	ELSE
		INSERT INTO grape.service (service_name, shared_secret)
			VALUES (_service_name, _shared_secret)
			RETURNING service_id INTO _service_id;
	END IF;

	RETURN _service_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.save_service(JSONB) RETURNS JSONB AS $$
DECLARE
	_service_id INTEGER;
BEGIN
	_service_name := $1->>'service_name';
	_shared_secret := $1->>'shared_secret';
	
	_service_id := grape.save_service(service_name, shared_secret);

	RETURN grape.api_success('service_id', _service_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.encrypt_message_for_service(_service_name TEXT, _message TEXT) RETURNS TEXT AS $$
DECLARE
	_s TEXT;
	_dkey TEXT;
	_encrypted TEXT;
BEGIN
	-- a request to log into ourselves
	IF grape.is_valid_service(_service_name) = FALSE  THEN
		IF _service_name = grape.get_value('service_name', '') THEN
			_s := ENCODE(gen_random_bytes(64), 'hex');
			PERFORM grape.save_service(_service_name, _s);
		ELSE
			-- Unknown service
			RAISE NOTICE 'Unknown service name %', _service_name;
			RETURN NULL;
		END IF;
	ELSE
		SELECT shared_secret INTO _s FROM grape.service WHERE service_name=_service_name::TEXT;
	END IF;

	_dkey := ENCODE(DIGEST(_s, 'sha256'), 'hex');
	_encrypted := grape.encrypt_message(_message::TEXT, _dkey, 'c5067fe37e0b025da44ec7578502c7e4');

	_s := NULL;
	_dkey := NULL;

	RETURN _encrypted;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.create_service_ticket(_service TEXT, _user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_service_ticket JSONB;
	_user RECORD;
	_start TIMESTAMPTZ;
BEGIN
	SELECT * INTO _user FROM grape."user" WHERE user_id=_user_id::INTEGER;

	_service_ticket := jsonb_build_object(
		'service', _service,
		'username', _user.username,
		'employee_guid', _user.employee_guid,
		'issued_at', NOW(),
		'valid_until', (NOW() + INTERVAL '8 hours'),
		'issued_by', grape.get_value('service_name', '')
	);

	RETURN _service_ticket::TEXT;
END; $$ LANGUAGE plpgsql;

-- encrypted service ticket
CREATE OR REPLACE FUNCTION grape.validate_service_ticket (_encrypted_service_ticket TEXT) RETURNS JSONB AS $$
DECLARE
	_service_name TEXT;
	_service_ticket JSONB;
	_dkey TEXT;
	_s TEXT;
BEGIN
	_service_name := grape.get_value('service_name', '');

	IF _service_name = '' THEN
		RETURN grape.api_error('Configuration error: service_name is not defined', -98);
	END IF;

	SELECT shared_secret INTO _s FROM grape.service WHERE service_name=_service_name;
	IF NOT FOUND THEN
		RETURN grape.api_error('Configuration error: service_secret is not set up', -98);
	END IF;

	_dkey := ENCODE(DIGEST(_s, 'sha256'), 'hex');
	_service_ticket := (grape.decrypt_message(_encrypted_service_ticket, _dkey, 'c5067fe37e0b025da44ec7578502c7e4'))::JSONB;

	_dkey := NULL;
	_s := NULL;

	RAISE NOTICE 'Service ticket: %', _service_ticket;

	IF _service_ticket->>'service' != _service_name THEN
		RETURN grape.api_error('Invalid service name', -5);
	END IF;

	-- TODO check time

	RETURN _service_ticket;
END; $$ LANGUAGE plpgsql;


