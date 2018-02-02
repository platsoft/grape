

CREATE OR REPLACE FUNCTION grape.user_update_auth_info(_user_id INTEGER, _field TEXT, _value TEXT) RETURNS VOID AS $$
	UPDATE grape."user" SET auth_info = auth_info || jsonb_build_object(_field, _value) WHERE user_id=_user_id::INTEGER;
$$ LANGUAGE sql;


