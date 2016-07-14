
/**
 *  passwords_hashed - false or true
 *  
 */

CREATE OR REPLACE FUNCTION grape.set_value(_name TEXT, _value TEXT, _hidden BOOLEAN DEFAULT FALSE) RETURNS TEXT AS $$
DECLARE
BEGIN
	DELETE FROM grape.setting WHERE name=_name::TEXT;
	INSERT INTO grape.setting (name, value, hidden) VALUES (_name, _value, _hidden);
	RETURN _value;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.get_value(_name TEXT, _default_value TEXT) RETURNS TEXT AS $$
DECLARE
	_val TEXT;
BEGIN
	SELECT value INTO _val FROM grape.setting WHERE name=_name;
	IF NOT FOUND OR _val IS NULL THEN
		RETURN _default_value;
	END IF;
	RETURN _val;
END; $$ LANGUAGE plpgsql;


