
/**
 * -1 = session not found
 * -2 = IP address of session does not match incoming IP
 */ 
CREATE OR REPLACE FUNCTION grape.validate_session (_session_id TEXT, _ip_address TEXT, _headers JSONB) RETURNS JSONB AS $$
DECLARE
	_session RECORD;
BEGIN
	SELECT * INTO _session FROM grape."session" WHERE session_id=_session_id::TEXT;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;

	IF _session.ip_address != _ip_address THEN
		RETURN NULL;
	END IF;
	
	-- TODO check headers as well

	RETURN grape.build_session_information(_session_id);
END; $$ LANGUAGE plpgsql;

