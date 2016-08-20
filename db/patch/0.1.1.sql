
ALTER TABLE grape."user" ADD COLUMN pg_role TEXT;
ALTER TABLE grape."user" ADD COLUMN local_only BOOLEAN DEFAULT false;

