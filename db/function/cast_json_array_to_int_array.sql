
/**
 * Convert JSON text array into Postgres INT array. Any invalid values gets ignored
 */
CREATE OR REPLACE FUNCTION cast_json_array_to_int_array (JSON) RETURNS INTEGER[] AS $$
DECLARE
	_ret INTEGER[];
	_val JSON;
	_txt TEXT;
	_i INTEGER;
BEGIN
	_ret := '{}';

	FOR _val IN SELECT json_array_elements($1) LOOP
		_txt := TRIM (BOTH '"' FROM _val::TEXT);
		BEGIN
			_i := _txt::INTEGER;
			_ret := array_append(_ret, _i);
		EXCEPTION WHEN OTHERS THEN
		END;
	END LOOP;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;


DROP CAST IF EXISTS (JSON AS INTEGER[]);
CREATE CAST (JSON AS INTEGER[]) WITH FUNCTION cast_json_array_to_int_array(JSON) AS IMPLICIT;

-- SELECT ('["1",2,"3"]'::JSON)::INTEGER[];

