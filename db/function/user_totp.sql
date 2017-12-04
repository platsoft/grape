
CREATE OR REPLACE FUNCTION grape.enable_totp(_user_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_auth_info JSONB;
	_new_key TEXT;
BEGIN
	IF grape.current_user_id() != _user_id THEN
		RETURN -2; -- permission denied
	END IF;

	SELECT COALESCE(auth_info, '{}'::JSONB) INTO _auth_info FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN -5; -- data not found
	END IF;

	IF _auth_info IS NULL THEN
		RETURN -6; -- data in invalid state
	END IF;
	
	_new_key := grape.random_string(20);

	_auth_info := _auth_info || jsonb_build_object('totp_status', 'pending verification', 'totp_key', _new_key);

	UPDATE grape."user" SET auth_info=_auth_info WHERE user_id=_user_id::INTEGER;

	RETURN 0;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.enable_totp (JSONB) RETURNS JSONB AS $$
DECLARE
	_key TEXT;
	_ret INTEGER;
	_user_id INTEGER;
	_username TEXT;
	_email TEXT;
	_provisioning_url TEXT;
	_issuer TEXT;
BEGIN
	_user_id := grape.current_user_id();
	IF _user_id IS NULL THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	_ret := grape.enable_totp(_user_id);

	IF _ret != 0 THEN
		RETURN grape.api_error('Unknown error (code ' || _ret || ')', _ret);
	ELSE
		SELECT auth_info->>'totp_key', username INTO _key, _username FROM grape."user" WHERE user_id=_user_id::INTEGER;

		_issuer := grape.urlencode(grape.get_value('product_name', 'Unknown'));

		_provisioning_url := FORMAT('otpauth://totp/%s:%s?secret=INSERT_SECRET_HERE&period=30&algorithm=SHA1&digits=6&issuer=%s', 
			_issuer, grape.urlencode(_username), _issuer);

		RETURN grape.api_success(jsonb_build_object('key', _key, 'provisioning_url', _provisioning_url));
	END IF;
END; $$ LANGUAGE plpgsql;


-- confirm TOTP on user's account
CREATE OR REPLACE FUNCTION grape.confirm_totp(JSONB) RETURNS JSONB AS $$
DECLARE
	_user_id INTEGER;
	_totp TEXT;
	_totp_provided TEXT;
	_auth_info JSONB;
BEGIN
	IF grape.current_user_id() IS NULL THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	_user_id := grape.current_user_id();

	SELECT auth_info INTO _auth_info FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;

	IF _auth_info IS NULL OR _auth_info->>'totp_status' != 'pending verification' THEN
		RETURN grape.api_error_invalid_data_state();
	END IF;

	_totp_provided := ($1->>'totp');
	_totp := grape.generate_totp(_auth_info->>'totp_key');

	IF _totp_provided != _totp THEN
		RETURN grape.api_error('OTP does not match', -400);
	ELSE
		_auth_info := _auth_info || jsonb_build_object('totp_status', 'ok');
		UPDATE grape."user" SET auth_info=_auth_info WHERE user_id=_user_id::INTEGER;
		RETURN grape.api_success();
	END IF;

END; $$ LANGUAGE plpgsql;

-- remove TOTP on user's account
CREATE OR REPLACE FUNCTION grape.remove_totp(JSONB) RETURNS JSONB AS $$
DECLARE
	_user_id INTEGER;
	_auth_info JSONB;
BEGIN
	IF grape.current_user_id() IS NULL THEN
		RETURN grape.api_error_permission_denied();
	END IF;

	_user_id := grape.current_user_id();

	SELECT auth_info INTO _auth_info FROM grape."user" WHERE user_id=_user_id::INTEGER;
	IF NOT FOUND THEN
		RETURN grape.api_error_data_not_found();
	END IF;

	_auth_info := _auth_info - 'totp_status';
	_auth_info := _auth_info - 'totp_key';

	UPDATE grape."user" SET auth_info=_auth_info WHERE user_id=_user_id::INTEGER;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

