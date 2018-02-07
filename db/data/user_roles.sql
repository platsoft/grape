INSERT INTO grape.access_role (role_name) 
VALUES 
	('guest'),
	('all'),
	('admin'),
	('pg_stat'), -- role that can view pg stats
	('switch_user') -- role that can switch to another user
ON CONFLICT (role_name) DO NOTHING;


INSERT INTO grape.access_path (role_name, regex_path) 
VALUES 
	('guest', '/session/new'),
	('guest', '/grape/login'),
	('guest', '/grape/session_ping'),
	('guest', '/grape/forgot_password'),
	('guest', '/grape/get_setting_value'),
	('guest', '/download_public_js_files'),
	('all', '/lookup/.*'),
	('all', '/grape/list'),
	('all', '/grape/api_list'),
	('all', '/grape/logout'),
	('all', '/download_public_js_files'),
	('admin', '.*')
ON CONFLICT (role_name, regex_path, method) DO NOTHING;