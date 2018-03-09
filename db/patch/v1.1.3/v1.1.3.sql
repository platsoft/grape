
SELECT grape.set_value('grape_version', '1.1.3');

ALTER TABLE grape."user" ADD COLUMN preferences JSONB DEFAULT '{}';
ALTER TABLE grape."user" DROP COLUMN pg_role;

DROP FUNCTION IF EXISTS grape.session_insert(JSON);

