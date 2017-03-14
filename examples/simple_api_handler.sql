

CREATE OR REPLACE FUNCTION simple_api_handler (JSON) RETURNS JSON AS $$
DECLARE
	_value INTEGER;
BEGIN
	_value := ($1->>'value')::INTEGER;

	_value := _value * 2;

	RETURN grape.api_success('result', _value);
END; $$ LANGUAGE plpgsql;

