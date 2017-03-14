
SELECT grape.list_query_whitelist_add('grape', 
	'{"user", '
	'"user_role", '
	'"user_access_role", '
	'"access_role", '
	'"report", '
	'"list_query_whitelist", '
	'"process", '
	'"schedule", '
	'"setting", '
	'"data_import", '
	'"data_import_type"}', '{admin}'::TEXT[]);

