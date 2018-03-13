BEGIN;

ALTER TABLE grape."user" ADD COLUMN auth_info JSONB DEFAULT '{}';

ALTER TABLE grape."user" DROP COLUMN external CASCADE;
ALTER TABLE grape."user" DROP COLUMN blame_id CASCADE;
ALTER TABLE grape."user" DROP COLUMN local_only CASCADE;

ALTER TABLE grape."user" ALTER COLUMN employee_info TYPE JSONB;

COMMIT;
