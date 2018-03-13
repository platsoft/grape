

DROP VIEW IF EXISTS grape.v_data_import;

CREATE VIEW grape.v_data_import AS
	SELECT
		data_import_id,
		filename,
		date_inserted,
		parameter,
		description,
		date_done,
		record_count,
		valid_record_count,
		data_import_status,
		processing_function,
		processing_param,
		result_table,
		result_schema,
		grape.username(user_id),
		data_processed,
		test_table_id
	FROM grape.data_import;

