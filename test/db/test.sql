
CREATE OR REPLACE FUNCTION grape.test (JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;
