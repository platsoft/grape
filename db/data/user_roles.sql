INSERT INTO grape.access_role (role_name) 
VALUES 
	('guest'),
	('all'),
	('admin'),
	('pg_stat'), -- role that can view pg stats
	('switch_user') -- role that can switch to another user
ON CONFLICT (role_name) DO NOTHING;


INSERT INTO grape.access_path (role_name, regex_path, method) 
VALUES 
	('guest', '/grape/session_ping', '{GET}'),
	('guest', '/download_public_js_files', '{GET}'),
	('all', '/grape/session_ping', '{GET}'),
	('all', '/grape/api_list', '{GET}'),
	('all', '/grape/logout', '{POST}'),
	('all', '/download_public_js_files', '{GET}')
ON CONFLICT (role_name, regex_path, method) DO NOTHING;

