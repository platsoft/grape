
/**
 * Generates and send a new password for this user
 * @input email address
 */
CREATE OR REPLACE FUNCTION grape.forgot_password(JSONB) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_user RECORD;
	_email TEXT;
	_sysname TEXT;
	_additional_data JSONB;
	_firstname TEXT;
BEGIN

	IF $1 ? 'email' THEN
		_email := $1->>'email';
	END IF;
	
	SELECT user_id INTO _user_id FROM grape."user" WHERE email=_email::TEXT;

	IF _user_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	IF $1 ? 'additional_data' THEN
		_additional_data := $1->'additional_data';
	ELSE
		_additional_data := '{}';
	END IF;

	_sysname := grape.get_value('product_name', '');

	SELECT u.*, 
		_sysname AS product_name, 
		grape.get_value('system_url', '') AS url,
		u.employee_info->>'firstname' AS firstname
	INTO _user 
	FROM grape."user" u 
	WHERE user_id=_user_id::INTEGER;

	IF _user.firstname IS NULL OR _user.firstname = '' THEN
		_user.firstname := _user.fullnames;
	END IF;

	_additional_data := _additional_data || to_jsonb(_user);

	PERFORM grape.send_email(_user.email::TEXT, 'login_details', _additional_data::JSON);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

