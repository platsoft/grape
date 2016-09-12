

CREATE OR REPLACE FUNCTION grape.send_email (_to TEXT, _template TEXT, _template_data JSON) RETURNS INTEGER AS $$
DECLARE
BEGIN

	PERFORM pg_notify('grape_send_email', json_build_object('email_template', _template, 'email', _to, 'template_data', _template_data)::TEXT);

	RETURN 0;
END; $$ LANGUAGE plpgsql;


