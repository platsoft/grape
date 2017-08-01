
CREATE OR REPLACE FUNCTION grape.check_notifications () RETURNS JSONB AS $$
DECLARE
	_r JSONB;
	_ret JSONB;
	_function_name TEXT;
	_function_schema TEXT;
BEGIN
	_ret := '[]'::JSONB;

	FOR _r IN EXECUTE FORMAT('SELECT %I.%I()', gn.function_schema, gn.function_name) FROM grape.notification_function gn WHERE active=TRUE LOOP
		_ret := _ret || _r;
	END LOOP;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


