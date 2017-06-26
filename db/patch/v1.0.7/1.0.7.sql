
-- Require: ../../function/table_permissions.sql
-- Require: ../../function/current_user_roles.sql
-- Require: ../../function/session.sql
-- Require: ../../function/user_network.sql

SELECT grape.set_value('grape_version', '1.0.7');
SELECT grape.add_setting ('user_ip_filter', 'false', 'Enable IP filtering on users', 'bool', false); 


