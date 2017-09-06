

CREATE OR REPLACE FUNCTION grape.switch_user (_target_user_id INTEGER) RETURNS TEXT AS $$
DECLARE
BEGIN
	-- Make sure the following conditions are met:
	--	Current user must have a valid session
	--	Current user must belong to a role called "switch_user"
	-- 	The target user must not belong to the admin role
	-- 	The target user must be active

	-- Log the current session out - grape.logout(json_build_object('session_id', _session_id);
	-- Create new session - grape.session_insert()
	-- Call grape.set_session_user_id(_target_user_id)

	-- Returns new session ID or NULL on error
	RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.switch_user (JSONB) RETURNS JSONB AS $$
DECLARE
BEGIN

	-- Call grape.switch_user
	-- Send back 
/*	SELECT jsonb_build_object(
		'success', true,
		'status', 'OK',
		'session_id', _session_id,
		'username', _user.username,
		'user_roles', (SELECT array_agg(role_name) FROM grape."user_role" WHERE user_id=_user.user_id::INTEGER),
		'fullnames', _user.fullnames,
		'email', _user.email,
		'employee_guid', _user.employee_guid
	) INTO _ret;
*/

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


