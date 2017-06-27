
SELECT grape.table_operation_whitelist_add('grape', 
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
	'"data_import_type"}', 

	'{admin}',
	'SELECT'
);

SELECT grape.table_operation_whitelist_add('grape',
	'{"access_role"}',
	'{"admin"}',
	'INSERT'
);

SELECT grape.table_operation_whitelist_add('grape',
	'{"access_role"}',
	'{"admin"}',
	'DELETE'
);

