
/**
 * Compares two JSON objects and returns an object containing fields that are different between the two.
 * 
 * If a field exists in j_old, but not in j_new, it is not included in the results
 * If a field exists in j_new, but not in j_old, it is included in the results
 * If a field is different, j_new is chosen
 */

CREATE OR REPLACE FUNCTION grape.json_diff (_old JSONB, _new JSONB) RETURNS JSONB AS $$
DECLARE
	_type_old TEXT;
	_type_new TEXT;
	_ret JSONB;
BEGIN
	_type_old := jsonb_typeof(_old);
	_type_new := jsonb_typeof(_new);
	
	IF _type_old != _type_new THEN
		RETURN _new;
	END IF;
	
	IF _type_old = 'object' THEN
		RETURN grape.json_object_diff (_old, _new);
	ELSIF _type_old = 'array' THEN
		RETURN grape.json_array_diff (_old, _new);
	ELSE
		IF _old::JSONB = _new::JSONB THEN
			RETURN NULL;
		ELSE
			RETURN _new;
		END IF;
	END IF;
	
END; $$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION grape.json_diff (_old JSON, _new JSON) RETURNS JSON AS $$
	SELECT grape.json_diff (_old::JSONB, _new::JSONB)::JSON;
$$ LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION grape.json_object_diff (_old JSONB, _new JSONB) RETURNS JSONB AS $$
DECLARE
	_ret JSONB := '{}';

	_key TEXT;
	_value JSON;

	_old_value JSON;

	_diff JSON;
BEGIN
	FOR _key, _value IN SELECT * FROM jsonb_each(_new) LOOP
		_old_value := jsonb_extract_path (_old, _key);
		
		IF _old_value IS NOT NULL THEN
			_diff := grape.json_diff (_old_value, _value);
			IF _diff IS NOT NULL THEN
				_ret := _ret || jsonb_build_object(_key, _diff);
			END IF;
		ELSE
			_ret := _ret || jsonb_build_object(_key, _value);
		END IF;
	END LOOP;

	RETURN _ret;
END; $$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Compare two JSON arrays and return any values that exists in _new but not in _old
 */
CREATE OR REPLACE FUNCTION grape.json_array_diff (_old JSONB, _new JSONB) RETURNS JSONB AS $$
DECLARE
	_value JSONB;
	_ret_fields JSONB[] := ARRAY[]::JSONB[];
BEGIN

	FOR _value IN SELECT jsonb_array_elements (_new) LOOP
		IF NOT _old::JSONB @> jsonb_build_array(_value) THEN
			_ret_fields := ARRAY_APPEND(_ret_fields, _value);
		END IF;
	END LOOP;

	RETURN to_jsonb(_ret_fields);
END; $$ LANGUAGE plpgsql IMMUTABLE;



