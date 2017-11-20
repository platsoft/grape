
DROP VIEW IF EXISTS grape.v_process_definitions;


ALTER TABLE grape.process DROP COLUMN count_new;
ALTER TABLE grape.process DROP COLUMN count_completed;
ALTER TABLE grape.process DROP COLUMN count_error;
ALTER TABLE grape.process DROP COLUMN count_running;

ALTER TABLE grape.process ADD COLUMN process_name TEXT;
UPDATE grape.process SET process_name=pg_function;

ALTER TABLE grape.process DROP CONSTRAINT process_function_schema_uq;
ALTER TABLE grape.process ADD CONSTRAINT process_name_uq UNIQUE (process_name);

ALTER TABLE grape.process ADD COLUMN start_function_name TEXT;
ALTER TABLE grape.process ADD COLUMN start_function_schema TEXT;
ALTER TABLE grape.process ADD COLUMN error_function_name TEXT;
ALTER TABLE grape.process ADD COLUMN error_function_schema TEXT;
ALTER TABLE grape.process ADD COLUMN end_function_name TEXT;
ALTER TABLE grape.process ADD COLUMN end_function_schema TEXT;

ALTER TABLE grape.process RENAME COLUMN param TO ui_param;

