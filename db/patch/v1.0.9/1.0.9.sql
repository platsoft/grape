
SELECT grape.set_value('grape_version', '1.0.9');

INSERT INTO grape.access_role (role_name) VALUES ('pg_stat'); -- role that can view pg stats

SELECT grape.table_permissions_add('pg_catalog', 
	'{pg_stat_user_functions,'
	'pg_stat_activity,'
	'pg_stat_replication}'::TEXT[], 

	'pg_stat',
	'SELECT'
);


