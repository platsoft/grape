

CREATE OR REPLACE FUNCTION grape.session_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user TEXT;
	_password TEXT;
	_ip_address TEXT;

	rec RECORD;

	_session_id TEXT;
	_found BOOLEAN;
BEGIN
	_user := $1->>'username';
	_password := $1->>'password';
	_ip_address := $1->>'ip_address';
	
	SELECT * INTO rec FROM grape."user" WHERE username=_user::TEXT;
	IF NOT FOUND THEN
		RETURN '{"success":"false","status":"ERROR","code":"1","message":"No such user"}'::JSON;
	END IF;

	IF rec.password != _password THEN
		RETURN '{"success":"false","status":"ERROR","code":"2","message":"Invalid password"}'::JSON;
	END IF;

	IF rec.active = false THEN
		RETURN '{"success":"false","status":"ERROR","code":"3","message":"User not active"}'::JSON;
	END IF;

	-- generate unique session id
	_found = TRUE;
	WHILE _found = TRUE LOOP
		_session_id := grape.random_string(15);
		IF EXISTS (SELECT session_id FROM grape."session" WHERE session_id=_session_id::TEXT) THEN
			_found := TRUE;
		ELSE
			_found := FALSE;
		END IF;
	END LOOP;

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity) VALUES (_session_id, _ip_address, rec.user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

	RETURN ('{"success":"true","code":"0","session_id":"' || _session_id || '","user_id":"' || rec.user_id || '","username":"' || _user || '"}')::JSON;

END; $$ LANGUAGE plpgsql;



