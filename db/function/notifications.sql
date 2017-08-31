
CREATE OR REPLACE FUNCTION grape.check_notifications () RETURNS JSONB AS $$
DECLARE
	_r JSONB;
	_ret JSONB;
	_function_name TEXT;
	_function_schema TEXT;
	_event TEXT;
BEGIN
	_ret := '[]'::JSONB;

	FOR _function_schema, _function_name, _event IN 
		SELECT gn.function_schema, gn.function_name, gn.emitted_event_name 
			FROM grape.notification_function gn 
			WHERE active=TRUE 
		LOOP
		BEGIN
			EXECUTE FORMAT('SELECT %I.%I()', _function_schema, _function_name) INTO _r;
			_ret := _ret || jsonb_build_object('event_name', _event, 'result', _r);
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Notification function error (%.%)', _function_schema, _function_name;
		END;
	END LOOP;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


