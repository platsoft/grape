INSERT INTO grape.access_role (role_name) VALUES ('guest');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/session/new');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/login');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/session_ping');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('guest', '/grape/forgot_password');

INSERT INTO grape.access_role (role_name) VALUES ('all');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('all', '/lookup/.*');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('all', '/grape/list');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('all', '/grape/api_list');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('all', '/grape/logout');


INSERT INTO grape.access_role (role_name) VALUES ('admin');
INSERT INTO grape.access_path (role_name, regex_path) VALUES ('admin', '.*');

