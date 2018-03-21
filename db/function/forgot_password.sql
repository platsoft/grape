
/**
 * Sends an email to user with password reset link
 */
CREATE OR REPLACE FUNCTION grape.reset_password_link(JSONB) RETURNS JSON AS $$
DECLARE
	_user RECORD;
	_rec RECORD;
	_email TEXT;
	_sysname TEXT;

	_reset_code TEXT;
	_reset_identifier TEXT;
	_firstname TEXT;
	_template_data JSONB;

	_otp TEXT;
BEGIN

	IF NOT $1 ? 'email' THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	SELECT * INTO _user FROM grape."user" WHERE email=($1->>'email');
	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;

	IF grape.get_user_totp_status(_user.user_id) = 'ok' THEN
		IF $1 ? 'otp' THEN
			_otp := $1->>'otp';
			IF _otp != grape.generate_totp_for_user(_user.user_id) THEN
				RETURN grape.api_error('OTP does not match', -400);
			END IF;
		ELSE
			RETURN grape.api_result_error('Missing OTP', -500);
		END IF;
	END IF;

	IF _user.employee_info IS NOT NULL AND _user.employee_info ? 'firstname' THEN
		_firstname := u.employee_info->>'firstname';
	ELSIF _user.fullnames IS NOT NULL THEN
		_firstname := _user.fullnames; -- TODO split out first word?
	ELSE
		_firstname := _user.username;
	END IF;

	_sysname := grape.get_value('product_name', 'Unknown');
	_reset_code := grape.random_string(30);
	_reset_identifier := grape.random_string(30);
	
	SELECT u.email, 
		_sysname AS product_name, 
		_reset_code AS reset_code,
		_reset_identifier AS reset_identifier,
		grape.get_value('system_url', 'missing setting system_url') AS system_url,
		_firstname AS firstname
	INTO _rec
	FROM grape."user" u 
	WHERE user_id=_user.user_id::INTEGER;

	_template_data := to_jsonb(_rec);

	PERFORM grape.send_email(_user.email::TEXT, 'reset_password_link', _template_data::JSON);

	UPDATE grape."user" SET auth_info = auth_info 
		|| jsonb_build_object(
			'password_reset_code', _reset_code, 
			'password_reset_identifier', _reset_identifier
		)
		WHERE user_id=_user.user_id::INTEGER;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.create_new_password(JSONB) RETURNS JSONB AS $$
DECLARE
	_encrypted_pw TEXT;
	_iv TEXT;
	_salt TEXT;
	_rounds INTEGER;
	_dklen INTEGER;
	_ri TEXT;
	_user RECORD;
	_reset_code TEXT;
	_decoded_pw TEXT;
BEGIN
	_encrypted_pw := ($1->>'new_password');
	_ri := ($1->>'ri');

	SELECT * INTO _user FROM grape."user" WHERE auth_info->>'password_reset_identifier'=_ri;
	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;

	IF _user.auth_info IS NOT NULL AND NOT _user.auth_info ? 'password_reset_code' THEN
		RETURN grape.api_error_invalid_data_state();
	END IF;
	
	_reset_code := (_user.auth_info)->>'password_reset_code';

	_iv := ($1->>'iv');
	_salt := ($1->>'salt');
	_rounds := ($1->>'rounds')::INTEGER;
	_dklen := ($1->>'dklen')::INTEGER;

	_reset_code := ENCODE(pbkdf2.pbkdf2('sha256', _reset_code, encode(_salt::BYTEA, 'base64'), _rounds, _dklen), 'hex');

	BEGIN
		_decoded_pw := grape.decrypt_message(_encrypted_pw, _reset_code, _iv);
	EXCEPTION WHEN OTHERS THEN
		RETURN grape.api_error('Invalid password reset code', -10);
	END;


	PERFORM grape.set_user_password(_user.user_id, _decoded_pw, FALSE);

	UPDATE grape."user" SET auth_info = (auth_info - 'password_reset_code') - 'password_reset_identifier' WHERE user_id=_user.user_id::INTEGER;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;


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
		RETURN grape.api_error_data_not_found();
	END IF;

	IF $1 ? 'additional_data' THEN
		_additional_data := $1->'additional_data';
	ELSE
		_additional_data := '{}';
	END IF;

	_sysname := grape.get_value('product_name', 'Unknown');
	_hashed_locally := grape.get_value('auth.hash_passwords', 'true')::BOOLEAN;

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

