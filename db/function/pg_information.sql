

CREATE OR REPLACE FUNCTION grape.pg_information(JSONB) RETURNS JSONB AS $$
DECLARE
	_ret JSONB;
BEGIN
	
	_ret := jsonb_build_object('status', 'OK', 
		'current_database', current_database(),
		'pg_postmaster_start_time', pg_postmaster_start_time(),
		'version', version(),
		'connection_count', (SELECT COUNT(*) FROM pg_stat_activity)
	);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

