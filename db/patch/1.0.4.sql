

CREATE OR REPLACE FUNCTION grape.send_email (_to TEXT, _template TEXT, _template_data JSON, _headers JSON) RETURNS INTEGER AS $$
DECLARE
BEGIN
	PERFORM pg_notify('grape_send_email', 
		json_build_object(
			'email_template', _template, 
			'email', _to, 
			'template_data', _template_data,
			'headers', _headers
	)::TEXT);

	RETURN 0;
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.send_email (_to TEXT, _template TEXT, _template_data JSON) RETURNS INTEGER AS $$
DECLARE
BEGIN
	PERFORM grape.send_email (_to, _template, _template_data, '{}'::JSON);

	RETURN 0;
END; $$ LANGUAGE plpgsql;



