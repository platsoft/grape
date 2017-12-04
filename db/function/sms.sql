
CREATE OR REPLACE FUNCTION grape.send_sms (JSON) RETURNS JSON AS $$
DECLARE
	_to TEXT;
	_template TEXT;
	_template_data JSON;
	_headers JSON;
BEGIN
	_to := $1->>'to';
	_template := $1->>'template';

	_template_data := $1->'template_data';
	
	PERFORM grape.send_email (_to, _template, _template_data);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.send_sms (_to TEXT, _template TEXT, _template_data JSON) RETURNS INTEGER AS $$
DECLARE
BEGIN
	PERFORM pg_notify('grape_send_sms', 
		json_build_object(
			'template', _template, 
			'email', _to, 
			'template_data', _template_data
	)::TEXT);

	RETURN 0;
END; $$ LANGUAGE plpgsql;



