
-- based off https://github.com/asio/otp/blob/master/sql/otp.sql
CREATE OR REPLACE FUNCTION grape.urlencode(in_str TEXT) RETURNS TEXT AS $$
DECLARE
	_i INT4;
	_temp VARCHAR;
	_ascii INT4;
	_result text := '';
BEGIN
	IF in_str IS NULL THEN
		RETURN NULL;
	END IF;

	FOR _i IN 1 .. LENGTH(in_str) LOOP
		_temp := SUBSTR(in_str, _i, 1);
		IF _temp ~ '[0-9a-zA-Z:/@._?#-]+' THEN
			_result := _result || _temp;
		ELSE
			_ascii := ASCII(_temp);
			IF _ascii > x'07ff'::int4 THEN
				RAISE EXCEPTION 'won''t deal with 3 (or more) byte sequences.';
			END IF;

			IF _ascii <= x'07f'::int4 THEN
				_temp := '%' || to_hex(_ascii);
			ELSE
				_temp := '%' || to_hex((_ascii & x'03f'::int4) + x'80'::int4);
				_ascii := _ascii >> 6;
				_temp := '%' || to_hex((_ascii & x'01f'::int4) + x'c0'::int4) || _temp;
			END IF;
			
			_result := _result || UPPER(_temp);
		END IF;
	END LOOP;
	
	RETURN _result;
END; $$ LANGUAGE plpgsql IMMUTABLE ;

-- SELECT  grape.urlencode('dw @ # )( platsoft.net ds ds');

