

CREATE OR REPLACE FUNCTION grape.json2xml(_data JSON, _root TEXT) RETURNS XML AS $$
DECLARE
	_el JSON;
	_ret XML;
	_xml XML;
	_key TEXT;
	_value TEXT;
	_type TEXT;
BEGIN
	_type := json_typeof (_data);

	IF _type = 'object' THEN
		FOR _key IN SELECT json_object_keys (_data) LOOP
			_xml := XMLCONCAT(_xml, json2xml(json_extract_path(_data, _key), _key));
		END LOOP;
		_ret := '<' || _root || '>' || _xml || '</' || _root || '>';
	ELSIF _type = 'array' THEN
		FOR _el IN SELECT json_array_elements (_data) LOOP
			_ret := XMLCONCAT(_ret, json2xml(_el, _root));
		END LOOP;
	ELSIF _type = 'string' THEN
		_ret := '<' || _root || '>' || SUBSTR(_data::TEXT, 2, length(_data::TEXT)-2) || '</' || _root || '>';
	ELSIF _type = 'number' THEN
		_ret := '<' || _root || '>' || _data || '</' || _root || '>';
	ELSIF _type = 'boolean' THEN
		_ret := '<' || _root || '>' || _data || '</' || _root || '>';
	ELSIF _type = 'null' THEN
		_ret := '<' || _root || ' />';
	END IF;
	
	RETURN _ret;
END; $$ LANGUAGE plpgsql;

-- SELECT json2xml ('{"blah":"dsda","sa":{"ggg":1,"gggh":null},"aa":[1,2,3]}'::JSON, 'o');

