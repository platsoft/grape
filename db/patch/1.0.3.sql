BEGIN;

CREATE TABLE IF NOT EXISTS grape.test_table(
	test_table_id serial NOT NULL,
	table_schema text NOT NULL,
	table_name text NOT NULL,
	description text,
	date_created timestamptz,
	user_id integer,
	date_updated timestamptz,
	CONSTRAINT test_table_id_pk PRIMARY KEY (test_table_id),
	CONSTRAINT test_table_uq UNIQUE (table_schema,table_name)
);

ALTER TABLE grape.data_import
	ALTER COLUMN date_inserted TYPE timestamptz,
	ALTER COLUMN date_inserted SET DEFAULT NOW(),
	ALTER COLUMN date_done TYPE timestamptz,
	ADD COLUMN user_id integer,
	ADD COLUMN data_processed tstzrange,
	ADD COLUMN test_table_id integer;

ALTER TABLE grape.data_import 
	ADD CONSTRAINT test_table_id_fk FOREIGN KEY (test_table_id)
		REFERENCES grape.test_table (test_table_id) MATCH FULL
		ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE grape.data_import_type
	-- DROP COLUMN full_description text,
	ADD COLUMN short_description text;

-- DROP INDEX IF EXISTS grape.data_import_idx CASCADE;
CREATE INDEX data_import_idx ON grape.data_import
	USING btree
	(
	  data_import_id
	);

-- DROP INDEX IF EXISTS grape.data_import_filename_idx CASCADE;
CREATE INDEX data_import_filename_idx ON grape.data_import
	USING btree
	(
	  filename
	);

-- DROP INDEX IF EXISTS grape.data_import_inserted_idx CASCADE;
CREATE INDEX data_import_inserted_idx ON grape.data_import
	USING btree
	(
	  date_inserted
	);

-- DROP INDEX IF EXISTS grape.data_import_process_idx CASCADE;
CREATE INDEX data_import_process_idx ON grape.data_import
	USING btree
	(
	  processing_function
	);

-- DROP INDEX IF EXISTS grape.data_import_user_idx CASCADE;
CREATE INDEX data_import_user_idx ON grape.data_import
	USING btree
	(
	  user_id
	);

-- DROP INDEX IF EXISTS grape.data_import_row_idx CASCADE;
CREATE INDEX data_import_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_row_id
	);

-- DROP INDEX IF EXISTS grape.data_import_id_row_idx CASCADE;
CREATE INDEX data_import_id_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_id
	);

-- DROP INDEX IF EXISTS grape.test_table_id_idx CASCADE;
CREATE INDEX test_table_id_idx ON grape.data_import
	USING btree
	(
	  test_table_id
	);

-- DROP INDEX IF EXISTS grape.test_table_idx CASCADE;
CREATE INDEX test_table_idx ON grape.test_table
	USING btree
	(
	  test_table_id
	);

-- DROP INDEX IF EXISTS grape.test_table_user_idx CASCADE;
CREATE INDEX test_table_user_idx ON grape.test_table
	USING btree
	(
	  user_id
	);

-- DROP INDEX IF EXISTS grape.test_table_created_idx CASCADE;
CREATE INDEX test_table_created_idx ON grape.test_table
	USING btree
	(
	  date_created
	);

-- DROP INDEX IF EXISTS grape.test_table_updated CASCADE;
CREATE INDEX test_table_updated ON grape.test_table
	USING btree
	(
	  date_updated
	);

COMMIT;