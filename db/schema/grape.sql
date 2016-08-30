-- Database generated with pgModeler (PostgreSQL Database Modeler).
-- pgModeler  version: 0.8.2
-- PostgreSQL version: 9.5
-- Project Site: pgmodeler.com.br
-- Model Author: ---


-- Database creation must be done outside an multicommand file.
-- These commands were put in this file only for convenience.
-- -- object: grape | type: DATABASE --
-- -- DROP DATABASE IF EXISTS grape;
-- CREATE DATABASE grape
-- ;
-- -- ddl-end --
-- 

-- object: grape | type: SCHEMA --
-- DROP SCHEMA IF EXISTS grape CASCADE;
CREATE SCHEMA grape;
-- ddl-end --

-- object: proc | type: SCHEMA --
-- DROP SCHEMA IF EXISTS proc CASCADE;
CREATE SCHEMA proc;
-- ddl-end --

SET search_path TO pg_catalog,public,grape,proc;
-- ddl-end --

-- object: hstore | type: EXTENSION --
-- DROP EXTENSION IF EXISTS hstore CASCADE;
CREATE EXTENSION hstore
      WITH SCHEMA public;
-- ddl-end --

-- object: grape.access_role | type: TABLE --
-- DROP TABLE IF EXISTS grape.access_role CASCADE;
CREATE TABLE grape.access_role(
	role_name text NOT NULL,
	CONSTRAINT access_role_pk PRIMARY KEY (role_name)

);
-- ddl-end --

-- object: grape.user_role | type: TABLE --
-- DROP TABLE IF EXISTS grape.user_role CASCADE;
CREATE TABLE grape.user_role(
	user_id integer NOT NULL,
	role_name text NOT NULL,
	CONSTRAINT user_role_pk PRIMARY KEY (user_id,role_name)

);
-- ddl-end --

-- object: grape.session | type: TABLE --
-- DROP TABLE IF EXISTS grape.session CASCADE;
CREATE TABLE grape.session(
	session_id text NOT NULL,
	ip_address text,
	user_id integer,
	date_inserted timestamp,
	last_activity timestamp,
	CONSTRAINT session_pk PRIMARY KEY (session_id)

);
-- ddl-end --

-- object: grape.access_path | type: TABLE --
-- DROP TABLE IF EXISTS grape.access_path CASCADE;
CREATE TABLE grape.access_path(
	role_name text NOT NULL,
	regex_path text NOT NULL,
	method text[] NOT NULL DEFAULT '{POST, PUT, GET}',
	CONSTRAINT access_path_pk PRIMARY KEY (role_name,regex_path,method)

);
-- ddl-end --
COMMENT ON COLUMN grape.access_path.method IS 'HTTP methods accepted by this path/route eg. (GET, POST, etc)';
-- ddl-end --

-- object: grape.user_history | type: TABLE --
-- DROP TABLE IF EXISTS grape.user_history CASCADE;
CREATE TABLE grape.user_history(
	user_history_id serial NOT NULL,
	user_id integer,
	date_inserted timestamp DEFAULT CURRENT_TIMESTAMP,
	data public.hstore,
	blame_id integer,
	CONSTRAINT user_history_id_pk PRIMARY KEY (user_history_id)

);
-- ddl-end --

-- object: grape."user" | type: TABLE --
-- DROP TABLE IF EXISTS grape."user" CASCADE;
CREATE TABLE grape."user"(
	user_id serial NOT NULL,
	password text,
	username text,
	email text,
	fullnames text,
	active boolean DEFAULT true,
	external smallint DEFAULT 0,
	blame_id integer,
	employee_guid uuid,
	employee_info json,
	pg_role text,
	local_only boolean DEFAULT FALSE,
	CONSTRAINT user_pk PRIMARY KEY (user_id),
	CONSTRAINT username_uq UNIQUE (username)

);
-- ddl-end --
COMMENT ON COLUMN grape."user".local_only IS 'If this is true, this user will not be linked to any external systems';
-- ddl-end --

-- object: grape.process | type: TABLE --
-- DROP TABLE IF EXISTS grape.process CASCADE;
CREATE TABLE grape.process(
	process_id serial NOT NULL,
	pg_function text,
	description text,
	param json,
	process_type text,
	function_schema text,
	CONSTRAINT process_pk PRIMARY KEY (process_id),
	CONSTRAINT process_uq UNIQUE (pg_function)

)WITH ( OIDS = TRUE );
-- ddl-end --
COMMENT ON COLUMN grape.process.process_type IS 'PG_FUNCTION; COMMAND';
-- ddl-end --

-- object: grape.e_schedule_status | type: TYPE --
-- DROP TYPE IF EXISTS grape.e_schedule_status CASCADE;
CREATE TYPE grape.e_schedule_status AS
 ENUM ('Running','Completed','Error','NewTask');
-- ddl-end --

-- object: grape.schedule_log | type: TABLE --
-- DROP TABLE IF EXISTS grape.schedule_log CASCADE;
CREATE TABLE grape.schedule_log(
	schedule_log_id serial NOT NULL,
	schedule_id integer,
	"time" timestamp,
	message text,
	CONSTRAINT schedule_log_pk PRIMARY KEY (schedule_log_id)

)WITH ( OIDS = TRUE );
-- ddl-end --

-- object: grape.schedule | type: TABLE --
-- DROP TABLE IF EXISTS grape.schedule CASCADE;
CREATE TABLE grape.schedule(
	schedule_id serial NOT NULL,
	process_id integer,
	time_sched timestamp,
	time_started timestamp,
	time_ended timestamp,
	pid integer,
	param json,
	user_id integer,
	logfile text,
	status grape.e_schedule_status DEFAULT 'NewTask',
	progress_completed integer,
	progress_total integer,
	CONSTRAINT schedule_pk PRIMARY KEY (schedule_id)

)WITH ( OIDS = TRUE );
-- ddl-end --
COMMENT ON COLUMN grape.schedule.time_sched IS 'Scheduled to start on';
-- ddl-end --
COMMENT ON COLUMN grape.schedule.time_started IS 'Actual start';
-- ddl-end --

-- object: grape.data_import | type: TABLE --
-- DROP TABLE IF EXISTS grape.data_import CASCADE;
CREATE TABLE grape.data_import(
	data_import_id serial NOT NULL,
	filename text,
	date_inserted timestamp DEFAULT NOW(),
	parameter json,
	description text,
	date_done timestamp,
	record_count integer,
	valid_record_count integer,
	data_import_status smallint,
	processing_function text,
	result_table text,
	result_schema text,
	CONSTRAINT data_import_pk PRIMARY KEY (data_import_id)

);
-- ddl-end --

-- object: grape.data_import_row | type: TABLE --
-- DROP TABLE IF EXISTS grape.data_import_row CASCADE;
CREATE TABLE grape.data_import_row(
	data_import_row_id serial NOT NULL,
	data_import_id integer,
	data json,
	processed boolean DEFAULT FALSE,
	result json,
	CONSTRAINT data_import_row_pk PRIMARY KEY (data_import_row_id)

);
-- ddl-end --

-- object: grape.setting | type: TABLE --
-- DROP TABLE IF EXISTS grape.setting CASCADE;
CREATE TABLE grape.setting(
	name text NOT NULL,
	value text,
	json_value json,
	hidden boolean DEFAULT FALSE,
	CONSTRAINT setting_pk PRIMARY KEY (name)

);
-- ddl-end --
COMMENT ON TABLE grape.setting IS 'System-wide settings';
-- ddl-end --

-- object: grape.system_registry | type: TABLE --
-- DROP TABLE IF EXISTS grape.system_registry CASCADE;
CREATE TABLE grape.system_registry(
	system_registry_id serial NOT NULL,
	product_name text,
	physical_host text,
	system_name text,
	guid uuid,
	public_key text,
	CONSTRAINT system_registry_pk PRIMARY KEY (system_registry_id)

);
-- ddl-end --

-- object: grape.system_routing | type: TABLE --
-- DROP TABLE IF EXISTS grape.system_routing CASCADE;
CREATE TABLE grape.system_routing(
	system_routing_id serial NOT NULL,
	final_destination_id integer,
	routing_via_id integer,
	CONSTRAINT system_routing_pk PRIMARY KEY (system_routing_id)

);
-- ddl-end --

-- object: grape.system_public_key | type: TABLE --
-- DROP TABLE IF EXISTS grape.system_public_key CASCADE;
CREATE TABLE grape.system_public_key(
	system_registry_id integer NOT NULL,
	data bytea,
	CONSTRAINT system_public_key_pk PRIMARY KEY (system_registry_id)

);
-- ddl-end --

-- object: grape.system_private | type: TABLE --
-- DROP TABLE IF EXISTS grape.system_private CASCADE;
CREATE TABLE grape.system_private(
	system_private_id serial NOT NULL,
	my_secret bytea,
	CONSTRAINT system_private_pk PRIMARY KEY (system_private_id)

);
-- ddl-end --

-- object: grape.data_import_type | type: TABLE --
-- DROP TABLE IF EXISTS grape.data_import_type CASCADE;
CREATE TABLE grape.data_import_type(
	processing_function text NOT NULL,
	full_description text,
	file_format_info text,
	function_schema text,
	CONSTRAINT data_import_type_pk PRIMARY KEY (processing_function)
	 WITH (FILLFACTOR = 100)

);
-- ddl-end --

-- object: pgcrypto | type: EXTENSION --
-- DROP EXTENSION IF EXISTS pgcrypto CASCADE;
CREATE EXTENSION pgcrypto
      WITH SCHEMA public;
-- ddl-end --

-- object: ix_schedule_log | type: INDEX --
-- DROP INDEX IF EXISTS grape.ix_schedule_log CASCADE;
CREATE INDEX ix_schedule_log ON grape.schedule_log
	USING btree
	(
	  schedule_id ASC NULLS LAST,
	  "time" ASC NULLS LAST
	);
-- ddl-end --

-- object: gu_username_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.gu_username_idx CASCADE;
CREATE INDEX gu_username_idx ON grape."user"
	USING btree
	(
	  username
	);
-- ddl-end --

-- object: grape.report | type: TABLE --
-- DROP TABLE IF EXISTS grape.report CASCADE;
CREATE TABLE grape.report(
	report_id serial NOT NULL,
	name text,
	description text,
	function_name text,
	function_schema text,
	input_fields json DEFAULT '{}'::JSON,
	report_type text,
	active boolean DEFAULT TRUE,
	cache_time interval,
	CONSTRAINT report_pk PRIMARY KEY (report_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.report.input_fields IS 'JSON array with fields, Ex. [{name: date_begin, type: date}, {name: date_end, type: date}]';
-- ddl-end --

-- object: grape.reports_executed | type: TABLE --
-- DROP TABLE IF EXISTS grape.reports_executed CASCADE;
CREATE TABLE grape.reports_executed(
	reports_executed_id serial NOT NULL,
	report_id integer,
	user_id integer,
	date_inserted timestamptz DEFAULT NOW(),
	result_table_schema text,
	result_table_name text,
	result_filename text,
	is_deleted boolean DEFAULT TRUE,
	report_seq integer,
	input_fields json,
	CONSTRAINT reports_executed_pk PRIMARY KEY (reports_executed_id)

);
-- ddl-end --

-- object: re_report_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.re_report_idx CASCADE;
CREATE INDEX re_report_idx ON grape.reports_executed
	USING btree
	(
	  report_id
	);
-- ddl-end --

-- object: report_name_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.report_name_idx CASCADE;
CREATE INDEX report_name_idx ON grape.report
	USING btree
	(
	  name
	);
-- ddl-end --

-- object: grape.session_history | type: TABLE --
-- DROP TABLE IF EXISTS grape.session_history CASCADE;
CREATE TABLE grape.session_history(
	session_id text NOT NULL,
	ip_address text,
	user_id integer,
	date_inserted timestamptz,
	last_activity timestamptz,
	date_logout timestamptz,
	CONSTRAINT session_history_pk PRIMARY KEY (session_id)

);
-- ddl-end --

-- object: grape.table_view | type: TABLE --
-- DROP TABLE IF EXISTS grape.table_view CASCADE;
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
-- ddl-end --

-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_role DROP CONSTRAINT IF EXISTS user_id_rel CASCADE;
ALTER TABLE grape.user_role ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: role_name_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_role DROP CONSTRAINT IF EXISTS role_name_rel CASCADE;
ALTER TABLE grape.user_role ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.session DROP CONSTRAINT IF EXISTS user_id_rel CASCADE;
ALTER TABLE grape.session ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: role_name_rel | type: CONSTRAINT --
-- ALTER TABLE grape.access_path DROP CONSTRAINT IF EXISTS role_name_rel CASCADE;
ALTER TABLE grape.access_path ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_history DROP CONSTRAINT IF EXISTS user_id_rel CASCADE;
ALTER TABLE grape.user_history ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: schedule_fk | type: CONSTRAINT --
-- ALTER TABLE grape.schedule_log DROP CONSTRAINT IF EXISTS schedule_fk CASCADE;
ALTER TABLE grape.schedule_log ADD CONSTRAINT schedule_fk FOREIGN KEY (schedule_id)
REFERENCES grape.schedule (schedule_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: process_fk | type: CONSTRAINT --
-- ALTER TABLE grape.schedule DROP CONSTRAINT IF EXISTS process_fk CASCADE;
ALTER TABLE grape.schedule ADD CONSTRAINT process_fk FOREIGN KEY (process_id)
REFERENCES grape.process (process_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: data_import_fk | type: CONSTRAINT --
-- ALTER TABLE grape.data_import_row DROP CONSTRAINT IF EXISTS data_import_fk CASCADE;
ALTER TABLE grape.data_import_row ADD CONSTRAINT data_import_fk FOREIGN KEY (data_import_id)
REFERENCES grape.data_import (data_import_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: re_reports_fk | type: CONSTRAINT --
-- ALTER TABLE grape.reports_executed DROP CONSTRAINT IF EXISTS re_reports_fk CASCADE;
ALTER TABLE grape.reports_executed ADD CONSTRAINT re_reports_fk FOREIGN KEY (report_id)
REFERENCES grape.report (report_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: session_user_fk | type: CONSTRAINT --
-- ALTER TABLE grape.session_history DROP CONSTRAINT IF EXISTS session_user_fk CASCADE;
ALTER TABLE grape.session_history ADD CONSTRAINT session_user_fk FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


