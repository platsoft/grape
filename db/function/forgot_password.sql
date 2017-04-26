
/**
 * Generates and send a new password for this user
 * If passwords in the system are hashed, a new password will be generated and sent
 * @input email address or user_id and username
 */
CREATE OR REPLACE FUNCTION grape.forgot_password(JSONB) RETURNS JSON AS $$
DECLARE
	_user_id INTEGER;
	_user RECORD;
	_email TEXT;
	_sysname TEXT;
	_additional_data JSONB;
	_firstname TEXT;
	_hashed_locally BOOLEAN;
	_new_password TEXT;
	_success BOOLEAN;
BEGIN

	IF $1 ? 'email' THEN
		_email := $1->>'email';
		SELECT user_id INTO _user_id FROM grape."user" WHERE email=_email::TEXT;
	ELSIF $1 ? 'user_id' AND $1 ? 'username' THEN
		SELECT user_id INTO _user_id FROM grape."user" 
			WHERE user_id=($1->>'user_id')::INTEGER
				AND username=$1->>'username';
	END IF;
	

	IF _user_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	IF $1 ? 'additional_data' THEN
		_additional_data := $1->'additional_data';
	ELSE
		_additional_data := '{}';
	END IF;

	_sysname := grape.get_value('product_name', 'Unknown');
	_hashed_locally := grape.get_value('hash_passwords', 'false')::BOOLEAN;

	IF _hashed_locally = true THEN
		-- we have to generate a new password
		_new_password := grape.random_string(6);

		_success := grape.set_user_password (_user_id, _new_password, false);

		IF _success = FALSE THEN
			RETURN grape.api_error();
		END IF;
	END IF;

	SELECT u.*, 
		_sysname AS product_name, 
		_sysname AS system_name, 
		grape.get_value('system_url', 'missing setting system_url') AS url,
		u.employee_info->>'firstname' AS firstname
	INTO _user 
	FROM grape."user" u 
	WHERE user_id=_user_id::INTEGER;

	IF _user.firstname IS NULL OR _user.firstname = '' THEN
		_user.firstname := _user.fullnames;
	END IF;

	IF _new_password IS NOT NULL THEN
		_user.password := _new_password;
	END IF;

	_additional_data := _additional_data || to_jsonb(_user);

	PERFORM grape.send_email(_user.email::TEXT, 'login_details', _additional_data::JSON);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

