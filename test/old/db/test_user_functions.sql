BEGIN;
CREATE OR REPLACE FUNCTION test_user_functions() RETURNS INTEGER AS $$
DECLARE
	_user_id INTEGER;
	_session_id TEXT;
	_obj JSONB;
BEGIN
	PERFORM grape.add_access_role('test_role');
	PERFORM grape.add_access_path('/test', '{test_role}', '{GET}');

	_user_id := grape.new_user('test', '{test_role}', 'test123');

	IF grape.username(_user_id) != 'test' THEN
		RAISE 'grape.username returned wrong value';
	END IF;

	PERFORM grape.set_session_user_id(_user_id);

	_obj := grape.session_insert('{"username": "test", "password": "test1231"}'::JSON);
	IF _obj->>'status' != 'ERROR' OR (_obj->>'code')::INTEGER != 2 THEN
		RAISE 'grape.session_insert returned wrong value for wrong password';
	END IF;
	
	_obj := grape.session_insert('{"username": "nonexistinguser", "password": "test1231"}'::JSON);
	IF _obj->>'status' != 'ERROR' OR (_obj->>'code')::INTEGER != 1 THEN
		RAISE 'grape.session_insert returned wrong value for invalid username';
	END IF;

	RETURN 0;

END; $$ LANGUAGE plpgsql;

SELECT test_user_functions();
DROP FUNCTION test_user_functions();

ROLLBACK;
