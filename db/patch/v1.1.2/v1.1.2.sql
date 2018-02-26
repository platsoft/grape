
SELECT grape.set_value('grape_version', '1.1.2');

SELECT grape.add_access_path('/download_public_js_files', '{guest,all}', '{GET}');

SELECT grape.table_permissions_add('grape', '{v_process_schedules}'::TEXT[], 'admin', 'SELECT');

DROP FUNCTION IF EXISTS grape.session_insert(INTEGER, TEXT);

