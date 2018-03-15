

CREATE OR REPLACE FUNCTION grape.switch_user (_target_user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_target_user RECORD;
	_ret JSONB;
BEGIN

	SELECT * INTO _target_user FROM grape."user" WHERE user_id=_target_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;

	-- Make sure the following conditions are met:
	--	Current user must have a valid session
	IF grape.current_user_id() IS NULL THEN
		RETURN NULL;
	END IF;

	--	Current user must belong to a role called "switch_user"
	IF grape.current_user_in_role('switch_user') = FALSE THEN
		RETURN NULL;
	END IF;

	-- 	The target user must not belong to the admin role
	IF grape.is_user_in_role(_target_user_id, 'admin') = TRUE THEN
		RETURN NULL;
	END IF;
	
	-- 	The target user must not belong to the "no_switch_user" role
	IF grape.is_user_in_role(_target_user_id, 'no_switch_user') = TRUE THEN
		RETURN NULL;
	END IF;

	-- 	The target user must be active
	IF _target_user.active != TRUE THEN
		RETURN NULL;
	END IF;

	-- Log the current session out - grape.logout(json_build_object('session_id', _session_id);
	-- Create new session - grape.session_insert()
	-- PERFORM grape.set_session_user_id(_target_user_id);

	-- Returns new session ID or NULL on error
	RETURN 'OK';
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.switch_user (JSONB) RETURNS JSONB AS $$
DECLARE
	_guid UUID;
	_user_id INTEGER;
	_username TEXT;

	_resulting_user_id INTEGER;
	_ret JSONB;
	_in JSONB;

	_check TEXT;
BEGIN

	_guid := ($1->>'guid')::UUID;
	_user_id := ($1->>'user_id')::INTEGER;
	_username := ($1->>'username')::TEXT;

	SELECT 
		u.user_id INTO _resulting_user_id 
	FROM grape."user" u
	WHERE 
		employee_guid=_guid::UUID 
		AND username=_username::TEXT;

	IF NOT FOUND OR _resulting_user_id != _user_id THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	_check := grape.switch_user(_user_id);

	IF _check = 'OK' THEN
		PERFORM grape.logout(NULL::JSON);

		_in := jsonb_build_object(
			'username', _username,
			'ip_address', $1->>'ip_address',
			'http_headers', $1->'http_headers'
		);

		_ret := grape.create_session_without_login(_in);
	ELSE
		_ret := grape.api_error_permission_denied();
	END IF;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.enable_no_switching(JSONB) RETURNS JSONB AS $$
DECLARE
BEGIN
	IF grape.current_user_id() IS NULL THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	IF grape.current_user_in_role('no_switch_user') = FALSE THEN
		PERFORM grape.add_user_to_access_role(grape.current_user_id(), 'no_switch_user');
	END IF;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.disable_no_switching(JSONB) RETURNS JSONB AS $$
DECLARE
BEGIN
	IF grape.current_user_id() IS NULL THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	IF grape.current_user_in_role('no_switch_user') = TRUE THEN
		PERFORM grape.remove_user_from_access_role(grape.current_username(), 'no_switch_user');
	END IF;
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


