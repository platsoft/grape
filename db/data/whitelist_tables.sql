
SELECT grape.table_permissions_add('grape', 
	'{user, '
	'user_role, '
	'user_access_role, '
	'v_active_users,'
	'access_role, '
	'report, '
	'list_query_whitelist, '
	'process, '
	'schedule, '
	'setting, '
	'v_table_permissions, '
	'network, '
	'v_user_networks,'
	'v_pg_functions,'
	'data_import, '
	'data_import_type}'::TEXT[], 

	'admin',
	'SELECT'
);

SELECT grape.table_permissions_add('grape',
	'{'
		'access_role,'
		'network,'
		'data_import_type'
	'}'::TEXT[],
	'{admin}'::TEXT[],
	'{INSERT,DELETE,UPDATE}'::TEXT[]
);

SELECT grape.table_permissions_add('pg_catalog', 
	'{pg_stat_user_functions,'
	'pg_stat_activity,'
	'pg_stat_replication}'::TEXT[], 

	'pg_stat',
	'SELECT'
);



