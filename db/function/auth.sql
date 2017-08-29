
CREATE OR REPLACE FUNCTION grape.create_TGT(_user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_user RECORD;
	_tgt JSONB;
BEGIN
	SELECT * INTO _user FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;
	
	_tgt := jsonb_build_object(
		'username', _user.username,
		'employee_guid', _user.employee_guid,
		'issued_at', NOW()
	);
	

	RETURN _tgt::TEXT;
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


