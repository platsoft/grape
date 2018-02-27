
SELECT grape.add_setting ('hash_passwords', 'true', 'Indicate whether passwords in grape.user is hashed', 'bool', false); 
SELECT grape.add_setting ('default_access_allowed', 'false', 'If a path is not found and this setting is true, access will be granted', 'bool', false); 
SELECT grape.add_setting ('product_name', '', 'Name of the current system', 'text', false);
SELECT grape.add_setting ('product_version', '', 'Product version', 'text', false);
SELECT grape.add_setting ('data_upload_schema', 'tmp', 'Default schema for data import tables', 'text', false); 
SELECT grape.add_setting ('disable_passwords', 'false', 'If true, authentication will not check whether passwords are correct', 'bool', false); 
SELECT grape.add_setting ('system_url', 'http://', 'URL to access system''s frontend', 'text', false);
SELECT grape.add_setting ('dataimport_in_background', 'false', 'Run data import processing functions in the background', 'bool', false); 
SELECT grape.add_setting ('filter_processes', 'false', 'Apply role based filtering on processes', 'bool', false); 
SELECT grape.add_setting ('user_ip_filter', 'false', 'Enable IP filtering on users', 'bool', false); 
SELECT grape.add_setting ('service_name', '', 'This service''s name (used when providing authentication)', 'text', false); 
SELECT grape.add_setting ('authentication_url', 'local', 'Authentication service URL', 'text', false); 
SELECT grape.add_setting ('ldap_users_dn', 'ou=Users,o=platsoft', 'DN for exposing our users as LDAP users', 'text', false); 
SELECT grape.add_setting ('basic_roles', '', 'Comma-separated list of basic user roles (all new users will be assigned these roles)', 'text', false); 
SELECT grape.add_setting ('test_table_schema', 'tmp', 'Default schema for data import test tables', 'text', false); 
SELECT grape.add_setting ('ldap_bind_password', 'Password123', 'LDAP bind password', 'text', true); 
SELECT grape.add_setting ('logging.log_api_calls_to_db', 'false', 'Log all API calls to DB', 'bool', false); 

