
DROP FUNCTION IF EXISTS grape.set_value(TEXT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS grape.set_value(TEXT, TEXT);
CREATE OR REPLACE FUNCTION grape.set_value(_name TEXT, _value TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	IF EXISTS (SELECT 1 FROM grape.setting WHERE name=_name::TEXT) THEN
		UPDATE grape.setting SET value=_value WHERE name=_name::TEXT;
	ELSE
		INSERT INTO grape.setting (name, value) VALUES (_name, _value);
	END IF;

	INSERT INTO grape.setting_history (setting_name, value, json_value, date_inserted, user_id) 
		VALUES (_name, _value, NULL, NOW(), current_user_id());
	
	PERFORM pg_notify('reload_settings', '');

	RETURN _value;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.get_value(_name TEXT, _default_value TEXT) RETURNS TEXT AS $$
DECLARE
	_val TEXT;
BEGIN
	SELECT value INTO _val FROM grape.setting WHERE name=_name::TEXT;
	IF NOT FOUND OR _val IS NULL THEN
		RETURN _default_value;
	END IF;
	RETURN _val;
END; $$ LANGUAGE plpgsql;

/**
 * @api_usage GrapeGetSetting
 * @api_url
 */
CREATE OR REPLACE FUNCTION grape.get_value(JSON) RETURNS JSON AS $$
DECLARE
	_val TEXT;
BEGIN
	SELECT value INTO _val FROM grape.setting WHERE name=($1->>'name')::TEXT AND hidden=false;
	
	RETURN grape.api_success(jsonb_build_object('value', _val)::JSON);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.setting(_name TEXT, _default_value TEXT) RETURNS TEXT AS $$
DECLARE
BEGIN
	RETURN grape.get_value (_name, _default_value); 
END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.add_setting(_name TEXT, _initial_value TEXT, _description TEXT, _data_type TEXT, _hidden BOOLEAN) RETURNS TEXT AS $$
DECLARE
BEGIN
	IF EXISTS (SELECT 1 FROM grape.setting WHERE name=_name::TEXT) THEN
		-- will not overwrite the value here
		UPDATE grape.setting SET 
			hidden=COALESCE(_hidden, hidden),
			description=COALESCE(_description, description), 
			data_type=COALESCE(_data_type , data_type)
			WHERE name=_name::TEXT;
	ELSE
		INSERT INTO grape.setting (name, value, hidden, description, data_type)
			VALUES (_name, _initial_value, _hidden, _description, _data_type);
	
		PERFORM pg_notify('reload_settings', _name);
	END IF;
	RETURN _initial_value;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.list_settings(JSON) RETURNS JSON AS $$
	SELECT grape.api_success('settings', json_agg(setting)) FROM (SELECT * FROM grape.setting ORDER BY name) setting;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.save_setting(JSON) RETURNS JSON AS $$
DECLARE
	_name TEXT;
	_value TEXT;
	_json_value JSON;
	_description TEXT;
	_hidden BOOLEAN;
	_data_type TEXT;
BEGIN
	IF json_extract_path($1, 'name') IS NOT NULL THEN
		_name := $1->>'name';
	END IF;
	IF json_extract_path($1, 'value') IS NOT NULL THEN
		_value := $1->>'value';
	END IF;
	IF json_extract_path($1, 'json_value') IS NOT NULL THEN
		_json_value := $1->'json_value';
	END IF;
	IF json_extract_path($1, 'description') IS NOT NULL THEN
		_description := $1->>'description';
	END IF;
	IF json_extract_path($1, 'data_type') IS NOT NULL THEN
		_data_type := $1->>'data_type';
	END IF;
	IF json_extract_path($1, 'hidden') IS NOT NULL THEN
		_hidden := ($1->>'hidden')::BOOLEAN;
	END IF;

	IF _name IS NULL THEN
		RETURN grape.api_error('Invalid input', -2);
	END IF;

	PERFORM grape.add_setting(_name, _value, _description, _data_type, _hidden);
	PERFORM grape.set_value(_name, _value);

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

