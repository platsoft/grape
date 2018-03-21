
SELECT grape.add_setting ('product_name', '', 'Name of the current system', 'text', false);
SELECT grape.add_setting ('product_version', '', 'Product version', 'text', false);
SELECT grape.add_setting ('service_name', '', 'A name for the local service', 'text', false); 
SELECT grape.add_setting ('system_url', 'http://', 'URL to access system''s frontend', 'text', false);


SELECT grape.add_setting ('grape_version', '1.1.3', 'Grape Version', 'text', false); 


SELECT grape.add_setting ('auth.hash_passwords', 'true', 'Indicate whether passwords in grape.user is hashed', 'bool', false); 
SELECT grape.add_setting ('auth.basic_roles', '', 'Comma-separated list of basic user roles (all new users will be assigned these roles)', 'text', false); 
SELECT grape.add_setting ('auth.default_access_allowed', 'false', 'If a path is not found and this setting is true, access will be granted', 'bool', false); 
SELECT grape.add_setting ('auth.user_ip_filter', 'false', 'Enable IP filtering on users', 'bool', false); 
SELECT grape.add_setting ('disable_passwords', 'false', 'If true, authentication will not check whether passwords are correct', 'bool', false); 

SELECT grape.add_setting ('logging.log_api_calls_to_db', 'false', 'Log all API calls to DB', 'bool', false); 


SELECT grape.add_setting ('filter_processes', 'false', 'Apply role based filtering on processes', 'bool', false); 

SELECT grape.add_setting ('dataimport.data_upload_schema', 'tmp', 'Default schema for data import tables', 'text', false); 
SELECT grape.add_setting ('dataimport.process_in_background', 'false', 'Run data import processing functions in the background', 'bool', false); 
SELECT grape.add_setting ('dataimport.test_table_schema', 'tmp', 'Default schema for data import test tables', 'text', false); 
