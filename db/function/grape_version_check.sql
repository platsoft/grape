

-- returns true if the grape version in the database is at least _check_version
CREATE OR REPLACE FUNCTION grape.grape_version_check (_check_version TEXT) RETURNS BOOLEAN AS $$
DECLARE
	_grape_version TEXT;
	_m TEXT[];
	_m_major INTEGER; -- stored
	_m_minor INTEGER;
	_m_rev INTEGER;

	_c TEXT[];
	_c_major INTEGER; -- check
	_c_minor INTEGER;
	_c_rev INTEGER;

BEGIN
	_grape_version := grape.setting('grape_version', '0.0.0');

	IF _grape_version = _check_version THEN
		RETURN TRUE;
	END IF;

	_m := string_to_array(_grape_version, '.');
	IF ARRAY_LENGTH(_m, 1) = 3 THEN
		_m_major := (_m[1])::INTEGER;
		_m_minor := (_m[2])::INTEGER;
		_m_rev := (_m[3])::INTEGER;
	ELSIF ARRAY_LENGTH(_m, 1) = 2 THEN
		_m_major := 0;
		_m_minor := (_m[1])::INTEGER;
		_m_rev := (_m[2])::INTEGER;
	ELSE
		_m_major := 0;
		_m_minor := 0;
		_m_rev := (_m[1])::INTEGER;
	END IF;

	
	_c := string_to_array(_check_version, '.');
	IF ARRAY_LENGTH(_c, 1) = 3 THEN
		_c_major := (_c[1])::INTEGER;
		_c_minor := (_c[2])::INTEGER;
		_c_rev := (_c[3])::INTEGER;
	ELSIF ARRAY_LENGTH(_c, 1) = 2 THEN
		_c_major := 0;
		_c_minor := (_c[1])::INTEGER;
		_c_rev := (_c[2])::INTEGER;
	ELSE
		_c_major := 0;
		_c_minor := 0;
		_c_rev := (_c[1])::INTEGER;
	END IF;

	IF _c_major > _m_major THEN
		RETURN FALSE;
	ELSIF _c_major < _m_major THEN
		RETURN TRUE;
	ELSIF _c_major = _m_major THEN

		IF _c_minor > _m_minor THEN
			RETURN FALSE;
		ELSIF _c_minor < _m_minor THEN
			RETURN TRUE;
		ELSIF _c_minor = _m_minor THEN
			IF _c_rev > _m_rev THEN
				RETURN FALSE;
			ELSIF _c_rev < _m_rev THEN
				RETURN TRUE;
			ELSIF _c_rev = _m_rev THEN
				RETURN TRUE;
			END IF;
		END IF;
	END IF;
END; $$ LANGUAGE plpgsql;



