
-- permissions for current user only
CREATE OR REPLACE VIEW grape.v_table_permissions AS 
	SELECT * FROM grape.check_all_table_permissions() 
	ORDER BY schema, tablename;	

