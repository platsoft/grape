
SELECT grape.add_setting ('hash_passwords', 'true', 'Indicate whether passwords in grape.user is hashed', 'bool', false); 
SELECT grape.add_setting ('allow_default_paths', 'false', 'If a path is not found and this setting is true, access will be granted', 'bool', false); 
SELECT grape.add_setting ('product_name', '', 'Name of the current system', 'text', false);
SELECT grape.add_setting ('product_version', '', 'Product version', 'text', false);
SELECT grape.add_setting ('data_upload_schema', 'tmp', 'Default schema for data import tables', 'text', false); 
SELECT grape.add_setting ('disable_passwords', 'false', 'If true, authentication will not check whether passwords are correct', 'bool', false); 
SELECT grape.add_setting ('system_url', '', 'URL to access system''s frontend', 'text', false);
SELECT grape.add_setting ('dataimport_in_background', 'false', 'Run data import processing functions in the background', 'bool', false); 
SELECT grape.add_setting ('filter_processes', 'false', 'Apply role based filtering on processes', 'bool', false); 
