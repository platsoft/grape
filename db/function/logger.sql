
CREATE OR REPLACE FUNCTION grape.log(_level TEXT, _message TEXT) RETURNS VOID AS $$
	SELECT pg_notify('log_' || _level, _message);
$$ LANGUAGE sql;

