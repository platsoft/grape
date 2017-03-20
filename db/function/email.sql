
CREATE OR REPLACE FUNCTION grape.send_email (JSON) RETURNS JSON AS $$
DECLARE
	_to TEXT;
	_template TEXT;
	_template_data JSON;
	_headers JSON;
BEGIN
	

	_to := $1->>'to';
	_template := $1->>'template';

	_headers := '{}';
	IF json_extract_path($1, 'headers') IS NOT NULL THEN
		_headers := $1->'headers';
	END IF;

	_template_data := $1->'template_data';
	
	PERFORM grape.send_email (_to, _template, _template_data, _headers);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

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



