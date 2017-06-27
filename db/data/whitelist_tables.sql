
SELECT grape.table_permissions_add('grape', 
	'{"user", '
	'"user_role", '
	'"user_access_role", '
	'"access_role", '
	'"report", '
	'"list_query_whitelist", '
	'"process", '
	'"schedule", '
	'"setting", '
	'"v_table_permissions", '
	'"network", '
	'"data_import", '
	'"data_import_type"}'::TEXT[], 

	'admin',
	'SELECT'
);

SELECT grape.table_permissions_add('grape',
	'{'
		'access_role,'
		'network'
	'}'::TEXT[],
	'{admin}'::TEXT[],
	'{INSERT,DELETE,UPDATE}'::TEXT[]
);


