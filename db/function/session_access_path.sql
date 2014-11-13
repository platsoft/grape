
DROP TYPE IF EXISTS grape.session_check_path_type CASCADE;
CREATE TYPE grape.session_check_path_type AS 
(
	session_id TEXT, 
	user_id INTEGER, 
	check_path TEXT, 
	check_path_result BOOLEAN, 
	check_method TEXT, 
	check_method_result BOOLEAN,  
	error_code INTEGER, 
	error_message TEXT, 
	user_role TEXT[]
);

CREATE OR REPLACE FUNCTION grape.session_check_path_select
(
	sess grape.session_check_path_type 
)
	RETURNS grape.session_check_path_type
	AS $$
DECLARE
	ret grape.session_check_path_type;
BEGIN
	-- select session, user, access roles, access paths
	SELECT 
		session_id, 
		"user".user_id, 
		sess.check_path, 
		TRUE,
		sess.check_method,
		TRUE,
		0, 
		'',
		(SELECT array_agg(role_name) FROM grape."user_role" WHERE "user_role".user_id="user".user_id) 
	INTO ret 
	FROM grape."session" 
	JOIN grape."user" USING (user_id) 
	JOIN grape.user_role USING (user_id) 
	JOIN grape.access_path USING (role_name) 
	WHERE session_id=sess.session_id::TEXT 
		AND (sess.check_path ~ regex_path)=TRUE 
		AND (sess.check_method = ANY (access_path.method)) 
	LIMIT 1;

	-- Fail (could not found a positive match)
	IF NOT FOUND THEN
		SELECT 
			session_id, 
			"user".user_id, 
			sess.check_path, 
			FALSE,
			sess.check_method,
			FALSE,
			1,
			'Permission denied',
			(SELECT array_agg(role_name) FROM grape."user_role" WHERE user_role.user_id="user".user_id) 
		INTO ret 
		FROM grape."session" 
		JOIN grape."user" USING (user_id) 
		WHERE session_id=sess.session_id::TEXT;

		-- Fail (session does not exist)
		IF NOT FOUND THEN
			SELECT 
				'', 
				0,
				sess.check_path, 
				TRUE,
				sess.check_method,
				TRUE,
				0, 
				'',
				'{guest}'::TEXT[]
			INTO ret 
			FROM grape.access_path 
			WHERE role_name='guest'::TEXT AND (sess.check_path ~ regex_path)=TRUE LIMIT 1;

			-- not in guest path list	
			IF NOT FOUND THEN
				SELECT 
					'', 
					0,
					sess.check_path, 
					FALSE,
					sess.check_method,
					FALSE,
					2, 
					'Invalid session',
					'{guest}'::TEXT[]
				INTO ret;
			END IF;
		END IF;
	END IF;

	RETURN ret;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.session_check_path_select
(
	_session_id TEXT,
	_check_path TEXT,
	_check_method TEXT
)
	RETURNS grape.session_check_path_type
	AS $$
DECLARE
	ret grape.session_check_path_type;
	inp grape.session_check_path_type;
BEGIN
	inp.session_id := _session_id;
	inp.check_path := _check_path;
	inp.check_method := _check_method;

	ret := grape.session_check_path_select(inp);

	UPDATE grape."session" SET last_activity=CURRENT_TIMESTAMP WHERE session_id=_session_id::TEXT;

	PERFORM set_config('grape.user_id'::TEXT, ret.user_id::TEXT, false);
	RETURN ret;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.set_session_user_id(JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;
	PERFORM set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
	RETURN '{}'::JSON;
END;
$$ LANGUAGE plpgsql;


