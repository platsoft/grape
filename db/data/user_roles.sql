
INSERT INTO grape.access_role (role_name) VALUES ('guest');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/session/new');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/lookup/.*');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/list');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/api_list');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/login');

INSERT INTO grape.access_role (role_name) VALUES ('admin');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('admin', '.*');

INSERT INTO grape.user_role (user_id, role_name) VALUES (999, 'admin');
