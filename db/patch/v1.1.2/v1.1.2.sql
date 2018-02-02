
SELECT grape.set_value('grape_version', '1.1.2');

SELECT grape.add_access_path('/download_public_js_files', '{guest,all}', '{GET}');

DROP FUNCTION IF EXISTS grape.session_insert(INTEGER, TEXT);

