
CREATE OR REPLACE FUNCTION grape.get_user_auth_info (JSONB) RETURNS JSONB AS $$
DECLARE
	_auth_info JSONB;
	_user_id INTEGER;
BEGIN
	

END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.user_update_auth_info(_user_id INTEGER, _field TEXT, _value TEXT) RETURNS VOID AS $$
	UPDATE grape."user" SET auth_info = COALESCE(auth_info, '{}'::JSONB) || jsonb_build_object(_field, _value) WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.get_user_auth_info (_user_id INTEGER) RETURNS TABLE (auth_server TEXT, totp_status TEXT) AS $$
	SELECT 
		COALESCE(auth_info->>'totp_status', ''),
		COALESCE(auth_info->>'auth_server', '') 
	FROM 
		grape."user" u
		WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;



