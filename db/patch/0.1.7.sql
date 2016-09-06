
CREATE TABLE grape.table_view(
	table_view_id serial NOT NULL,
	table_name text,
	table_schema text,
	columns jsonb,
	settings jsonb,
	primary_key_column text,
	onclick_url text,
	CONSTRAINT table_view_pk PRIMARY KEY (table_view_id)

);


CREATE TABLE grape.auto_scheduler(
	process_id integer NOT NULL,
	scheduled_interval interval,
	dow varchar(7) DEFAULT '1111111',
	days_of_month text DEFAULT '*',
	day_time time,
	run_as_user_id INTEGER,
	CONSTRAINT auto_scheduler_pk PRIMARY KEY (process_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.auto_scheduler.dow IS 'days of week represented by 0 and 1; starting on Sunday';
-- ddl-end --
COMMENT ON COLUMN grape.auto_scheduler.days_of_month IS 'Comma separated list of days of month';
-- ddl-end --

-- object: sch_process_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.sch_process_idx CASCADE;
CREATE INDEX sch_process_idx ON grape.schedule
	USING btree
	(
	  process_id
	);



