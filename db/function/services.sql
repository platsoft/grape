/* Service roles:
 * TICKET_ISSUER - this service can issue tickets for us - shared_key contains the encryption key that the other service uses to encrypt messages for us
 * SERVICE_TICKET - we can issue tickets for this service, using shared_key
 * LDAP_AUTH - this service is used to find remote users (matching user.auth_info->>'auth_server')
 * 
 */


CREATE OR REPLACE FUNCTION grape.is_valid_service(_name TEXT, _role TEXT) RETURNS BOOLEAN AS $$
	SELECT COALESCE((SELECT TRUE FROM grape.service WHERE service_name=_name::TEXT AND role=_role::TEXT) , FALSE);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.get_service_shared_key (_name TEXT, _role TEXT) RETURNS TEXT AS $$
	SELECT shared_secret FROM grape.service WHERE service_name=_name::TEXT AND role=_role::TEXT;
$$ LANGUAGE sql;


CREATE OR REPLACE FUNCTION grape.save_service(_service_id INTEGER, _service_name TEXT, _shared_secret TEXT, _role TEXT) RETURNS INTEGER AS $$
DECLARE
	_new_service_id INTEGER;
BEGIN
	_shared_secret := TRANSLATE(_shared_secret, E'\n', '');
	IF _service_id IS NULL THEN
		IF grape.is_valid_service(_service_name, _role) THEN
			RETURN NULL;
		END IF;
		INSERT INTO grape.service (service_name, shared_secret, role)
			VALUES (_service_name, _shared_secret, _role)
			RETURNING _service_id INTO _new_service_id;
	ELSE
		UPDATE grape.service SET shared_secret=_shared_secret WHERE service_name=_service_name::TEXT AND role=_role::TEXT;
	END IF;

	RETURN _new_service_id;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.save_service(JSONB) RETURNS JSONB AS $$
DECLARE
	_service_id INTEGER;
	_service_name TEXT;
	_shared_secret TEXT;
	_role TEXT;
BEGIN
	IF $1 ? 'service_id' THEN
		_service_id := ($1->>'service_id')::INTEGER;
	END IF;

	_service_name := $1->>'service_name';
	_shared_secret := $1->>'shared_secret';
	_role := $1->>'role';

	_service_id := grape.save_service(_service_id, _service_name, _shared_secret, _role);

	RETURN grape.api_success('service_id', _service_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.encrypt_message_for_service(_service_name TEXT, _message TEXT) RETURNS TEXT AS $$
DECLARE
	_s TEXT;
	_dkey TEXT;
	_encrypted TEXT;
BEGIN
	_s := grape.get_service_shared_key(_service_name, 'SERVICE_TICKET');
	IF _s IS NULL THEN
		IF _service_name = grape.get_value('service_name', '') THEN
			_s := ENCODE(gen_random_bytes(64), 'hex');
			PERFORM grape.save_service(NULL, _service_name, _s, 'SERVICE_TICKET');
			PERFORM grape.save_service(NULL, _service_name, _s, 'TICKET_ISSUER');
		ELSE
			-- Unknown service
			RAISE NOTICE 'Unknown service name %', _service_name;
			RETURN NULL;
		END IF;
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
CREATE OR REPLACE FUNCTION grape.validate_service_ticket (_encrypted_service_ticket TEXT, _issued_by TEXT) RETURNS JSONB AS $$
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

	_s := grape.get_service_shared_key(_issued_by, 'TICKET_ISSUER');
	IF _s IS NULL THEN
		RETURN grape.api_error('Configuration error: The service who issued the ticket is not set up to issue service tickets for us', -98);
	END IF;

	_dkey := ENCODE(DIGEST(_s, 'sha256'), 'hex');
	BEGIN
		_service_ticket := (grape.decrypt_message(_encrypted_service_ticket, _dkey, 'c5067fe37e0b025da44ec7578502c7e4'))::JSONB;
	EXCEPTION WHEN OTHERS THEN
		RETURN grape.api_error('Failed to decrypt message', -5);
	END;

	_dkey := NULL;
	_s := NULL;

	RAISE NOTICE 'Service ticket: %', _service_ticket;

	IF _service_ticket->>'service' != _service_name THEN
		RETURN grape.api_error('Invalid service name', -5);
	END IF;

	-- TODO check time

	RETURN _service_ticket;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.delete_service(JSONB) RETURNS JSONB AS $$
DECLARE
BEGIN
	IF NOT $1 ? 'service_id' THEN
		RETURN grape.api_error_invalid_field('service_id');
	END IF;

	DELETE FROM grape.service WHERE service_id=($1->>'service_id')::INTEGER;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


