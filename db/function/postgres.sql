
/*
CREATE OR REPLACE FUNCTION grape.pg_list_tables (JSON) RETURNS JSON AS $$
DECLARE
BEGIN
	
END; $$ LANGUAGE plpgsql;

*/

/**
 * Provide tablename and schema
 */
CREATE OR REPLACE FUNCTION grape.pg_table_information (JSON) RETURNS JSON AS $$
DECLARE
	_tname TEXT;
	_schema TEXT;

	_columns JSON;
BEGIN
	 -- TODO check that user has access to table in list_query_whitelist first, using grape.table_operation_check_permissions

	_tname := ($1->>'tablename');
	_schema := ($1->>'schema');
	
	SELECT json_agg(a.*) INTO _columns FROM (
		SELECT 
			column_name, 
			column_default, 
			is_nullable, 
			data_type 
		FROM 
			information_schema.columns 
		WHERE 
			table_schema=_schema::TEXT 
			AND table_name=_tname::TEXT ) a;
	
	RETURN grape.api_success('columns', _columns);
END; $$ LANGUAGE plpgsql;

