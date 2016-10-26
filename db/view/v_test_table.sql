CREATE OR REPLACE VIEW grape.v_test_table AS
	SELECT 
		test_table_id,
		table_schema,
		table_name,
		description,
		date_created,
		user_id,
		date_updated,
		grape.username(user_id) AS username
	FROM grape.test_table;
