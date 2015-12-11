

CREATE OR REPLACE FUNCTION grape.session_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user TEXT;
	_password TEXT;
	_ip_address TEXT;

	rec RECORD;

	_session_id TEXT;
	_found BOOLEAN;

	_user_roles TEXT[];

	_ret JSON;
BEGIN
	_user := $1->>'username';
	_password := $1->>'password';
	_ip_address := $1->>'ip_address';
	
	SELECT * INTO rec FROM grape."user" WHERE username=_user::TEXT;
	IF NOT FOUND THEN
		RAISE DEBUG 'User % login failed. No such user', _user;
		RETURN '{"success":"false","status":"ERROR","code":"1","message":"No such user"}'::JSON;
	END IF;

	IF crypt(_password, rec.password) != rec.password THEN
		RAISE DEBUG 'User % login failed. Password does not match', _user;
		RETURN '{"success":"false","status":"ERROR","code":"2","message":"Invalid password"}'::JSON;
	END IF;

	IF rec.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
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
	
	RAISE DEBUG 'User % logged in successfuly from %. Session ID is now %', _user, _ip_address, _session_id;

	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=rec.user_id::INTEGER;

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity) VALUES (_session_id, _ip_address, rec.user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

	SELECT to_json(a) INTO _ret FROM (
		SELECT 'true' AS "success", 
			'OK' AS "status", 
			0 AS "code", 
			_session_id AS "session_id",
			rec.user_id AS "user_id",
			_user AS "username",
			_user_roles AS "user_roles" 
		) a;
	
	RETURN _ret;
END; $$ LANGUAGE plpgsql;



