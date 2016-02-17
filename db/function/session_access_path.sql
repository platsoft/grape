
DROP TYPE IF EXISTS grape.access_result_type CASCADE;
CREATE TYPE grape.access_result_type AS
(
	result_code INTEGER,
	user_id INTEGER,
	session_id TEXT
);

/**
 * Check access to a path for a session
 *
 * 0 - success
 * 1 - Invalid session (session does not exist)
 * 2 - Permission denied
 * 9 - The path could not be found, and default_access_allowed setting is false
 *
 *
 * Special roles for access paths:
 * guest - allows immediately
 * all - allows any access with a valid user_id
 */
CREATE OR REPLACE FUNCTION grape.check_session_access (_session_id TEXT, _check_path TEXT, _check_method TEXT)
	RETURNS grape.access_result_type AS $$
DECLARE
	_path_role TEXT[];
	_user_id INTEGER;
BEGIN
	SELECT user_id INTO _user_id FROM grape."session" WHERE session_id=_session_id::TEXT;

	-- get the path
	SELECT array_agg(role_name) INTO _path_role FROM grape.access_path WHERE (_check_path ~ regex_path)=TRUE;
	IF NOT FOUND THEN
		-- not found, allow it?
		IF grape.get_value('default_access_allowed', 'true') = 'true' THEN
			RETURN (0, _user_id, _session_id)::grape.access_result_type;
		ELSE
			RETURN (9, _user_id, _session_id)::grape.access_result_type;
		END IF;
	END IF;

	-- everyone (event when not logged in) has access to "guest" role
	IF 'guest' = ANY (_path_role) THEN
		RETURN (0, _user_id, _session_id)::grape.access_result_type;
	END IF;

	-- Invalid session
	IF _user_id IS NULL THEN
		RETURN (1, _user_id, _session_id)::grape.access_result_type;
	END IF;

	-- everyone that is logged in has access to the "all" role
	IF 'all' = ANY (_path_role) THEN
		RETURN (0, _user_id, _session_id)::grape.access_result_type;
	END IF;


	-- role exists for this user and role
	IF EXISTS (SELECT 1 FROM grape.user_role WHERE user_id=_user_id::INTEGER AND role_name = ANY (_path_role)) THEN
		RETURN (0, _user_id, _session_id)::grape.access_result_type;
	END IF;

	RETURN (2, _user_id, _session_id)::grape.access_result_type;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.set_session_user_id(JSON) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
BEGIN
	_user_id := ($1->>'user_id')::INTEGER;
	PERFORM set_config('grape.user_id'::TEXT, _user_id::TEXT, false);
	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;



