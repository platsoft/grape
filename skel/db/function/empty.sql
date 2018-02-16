
CREATE OR REPLACE FUNCTION demo.empty_handler (JSONB) RETURNS JSONB AS $$
DECLARE
BEGIN

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

