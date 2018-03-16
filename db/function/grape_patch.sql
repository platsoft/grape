

CREATE OR REPLACE FUNCTION grape.patch_start(_system TEXT, _version INTEGER, _note TEXT, _log_file TEXT) RETURNS BOOLEAN AS $$
	INSERT INTO grape.patch (
		system,
		version,
		start_time,
		end_time,
		status,
		log_file,
		note)
	VALUES (
		_system,
		_version,
		NOW(),
		NULL,
		'START',
		_log_file,
		_note
	) RETURNING TRUE;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION grape.patch_check(_system TEXT, _version INTEGER) RETURNS BOOLEAN AS $$
	SELECT EXISTS (
		SELECT 1 FROM grape.patch WHERE system=_system::TEXT AND version>=_version::INTEGER
	);
$$ LANGUAGE sql;

