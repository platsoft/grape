
CREATE OR REPLACE FUNCTION grape.is_absolute(_path TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	-- TODO cater for MS windows paths
	IF LEFT(_path, 1) = '/' THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END; $$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION grape.is_directory(_path TEXT) RETURNS BOOLEAN AS $$
DECLARE
BEGIN
	-- TODO cater for MS windows paths
	IF RIGHT(_path, 1) = '/' THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END; $$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION grape.sanitize_path_to_array(_path TEXT) RETURNS TEXT[] AS $$
DECLARE
	_absolute BOOLEAN;
	_parts TEXT[];
	_part TEXT;
	_lpart TEXT;
	_new_parts TEXT[];
	_i INTEGER;
BEGIN
	IF _path = '' OR _path IS NULL THEN
		RETURN '{}'::TEXT[];
	END IF;

	_absolute := grape.is_absolute(_path);

	_parts := string_to_array(_path, '/');
	_new_parts := '{}';

	_i := 0;
	
	FOREACH _part IN ARRAY _parts LOOP
		_lpart := COALESCE(_new_parts[_i], '');
		IF _part != '' THEN
			IF _part = '..' THEN
				IF ARRAY_LENGTH(_new_parts, 1) IS NULL THEN
					IF _absolute = FALSE THEN
						_new_parts := ARRAY_APPEND(_new_parts, '..');
						_i := _i + 1;
					END IF;
				ELSIF _lpart = '..' THEN
					_new_parts := ARRAY_APPEND(_new_parts, '..');
					_i := _i + 1;
				ELSE
					_new_parts := COALESCE(_new_parts[:_i - 1], '{}'::TEXT[]);
					_i := _i - 1;
				END IF;
			ELSE
				_i := _i + 1;
				_new_parts := ARRAY_APPEND(_new_parts, _part);
			END IF;
		END IF;
	END LOOP;

	_new_parts := ARRAY_REMOVE(_new_parts, '.');

	RETURN _new_parts;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.sanitize_path(_path TEXT) RETURNS TEXT AS $$
DECLARE
	_ret TEXT;
	_new_parts TEXT[];
BEGIN
	_new_parts := grape.sanitize_path_to_array(_path);
	_ret := array_to_string(_new_parts, '/');
	IF grape.is_absolute(_path) THEN
		_ret := '/' || _ret;
	END IF;
	IF grape.is_directory(_path) AND _ret != '/' THEN
		_ret := _ret || '/';
	END IF;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

/**
Testing: grape.sanitize_path
	Test: grape.sanitize_path('/etc/hosts') => '/etc/hosts'
	Test: grape.sanitize_path('etc/hosts') => 'etc/hosts'
	Test: grape.sanitize_path('/etc//hosts') => '/etc/hosts'
	Test: grape.sanitize_path('////etc//hosts') => '/etc/hosts'
	Test: grape.sanitize_path('/foo/bar1/../bar2') => '/foo/bar2'
	Test: grape.sanitize_path('/foo/bar1/../bar2/bar3/bar4/../bar5') => '/foo/bar2/bar3/bar5'
	Test: grape.sanitize_path('/foo/bar1/./bar2') => '/foo/bar1/bar2'
	Test: grape.sanitize_path('/foo/bar1/./../bar2/..') => '/foo'
	Test: grape.sanitize_path('/foo/bar1/./bar2/bar3/bar4/../bar5') => '/foo/bar1/bar2/bar3/bar5'
	Test: grape.sanitize_path('../../dsds/..//etc/tmp') => '../../etc/tmp'
	Test: grape.sanitize_path('../fdsq/..//etc/../network//./..//hosts') => '../network/hosts'
	Test: grape.sanitize_path('/fdsq/..//etc/./network//../..//hosts') => '/etc/hosts'
*/

CREATE OR REPLACE FUNCTION grape.path_parent(_path TEXT) RETURNS TEXT AS $$
DECLARE
	_path_parts TEXT[];
	_ret TEXT;
BEGIN
	_path_parts := grape.sanitize_path_to_array(_path);
	_path_parts := _path_parts[:ARRAY_LENGTH(_path_parts, 1)-1];

	_ret := array_to_string(_path_parts, '/');

	IF grape.is_absolute(_path) THEN
		_ret := '/' || _ret;
	END IF;

	IF _ret != '/' THEN
		_ret := _ret || '/';
	END IF;

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

-- returns the last portion of a path
CREATE OR REPLACE FUNCTION grape.path_basename(_path TEXT) RETURNS TEXT AS $$
DECLARE
	_path_parts TEXT[];
	_i INTEGER;
BEGIN
	_path_parts := grape.sanitize_path_to_array(_path);
	_i := ARRAY_LENGTH(_path_parts, 1);
	IF (_path_parts[_i:_i])[1] = '' THEN
		RETURN (_path_parts[_i-1:_i-1])[1] || '/';
	ELSE
		RETURN (_path_parts[_i:_i])[1];
	END IF;
END; $$ LANGUAGE plpgsql;


