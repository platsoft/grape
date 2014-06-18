
/**
 * Convert JSON text array into Postgres TEXT array
 */
CREATE OR REPLACE FUNCTION cast_json_array_to_text_array (JSON) RETURNS TEXT[] AS $$
DECLARE
	_ret TEXT[];
	_l INTEGER;
	_i INTEGER;
	_val JSON;
	_txt TEXT;
BEGIN
	_ret := '{}';

	FOR _val IN SELECT json_array_elements($1) LOOP
		_txt := TRIM (BOTH '"' FROM _val::TEXT);
		_ret := array_append(_ret, _txt);
	END LOOP;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

DROP CAST IF EXISTS (JSON AS TEXT[]);
CREATE CAST (JSON AS TEXT[]) WITH FUNCTION cast_json_array_to_text_array(JSON) AS IMPLICIT;

