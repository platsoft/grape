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
	date_inserted timestamptz DEFAULT CURRENT_TIMESTAMP,
	data jsonb,
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
	employee_guid uuid,
	employee_info jsonb,
	pg_role text,
	auth_info jsonb,
	CONSTRAINT user_pk PRIMARY KEY (user_id),
	CONSTRAINT username_uq UNIQUE (username)

);
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
	process_category text,
	count_new integer DEFAULT 0,
	count_completed integer DEFAULT 0,
	count_error integer DEFAULT 0,
	count_running integer DEFAULT 0,
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
	auto_scheduler_id integer,
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
	date_inserted timestamptz DEFAULT NOW(),
	parameter json,
	description text,
	date_done timestamptz,
	record_count integer,
	valid_record_count integer,
	data_import_status smallint,
	processing_function text,
	processing_param json,
	result_table text,
	result_schema text,
	user_id integer,
	data_processed tstzrange,
	test_table_id integer,
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
	description text,
	data_type text,
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
	short_description text,
	file_format_info text,
	function_schema text,
	param_definition json,
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
	function_name text,
	function_schema text,
	ui_params json DEFAULT '{}'::JSON,
	output_format text,
	active boolean DEFAULT TRUE,
	cache_time interval,
	report_category_id integer,
	CONSTRAINT report_pk PRIMARY KEY (report_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.report.ui_params IS 'JSON array with fields, Ex. [{name: date_begin, type: date}, {name: date_end, type: date}]';
-- ddl-end --
COMMENT ON COLUMN grape.report.output_format IS 'Structure of the output data - TEXT or ROW or TABLE';
-- ddl-end --
COMMENT ON COLUMN grape.report.cache_time IS 'How long a result is valid for';
-- ddl-end --

-- object: grape.reports_executed | type: TABLE --
-- DROP TABLE IF EXISTS grape.reports_executed CASCADE;
CREATE TABLE grape.reports_executed(
	reports_executed_id serial NOT NULL,
	report_id integer,
	user_id integer,
	date_inserted timestamptz DEFAULT NOW(),
	is_deleted boolean DEFAULT TRUE,
	report_seq integer,
	params json,
	report_template_id integer,
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

-- -- object: grape.table_view | type: TABLE --
-- -- DROP TABLE IF EXISTS grape.table_view CASCADE;
-- CREATE TABLE grape.table_view(
-- 	table_view_id serial NOT NULL,
-- 	table_name text,
-- 	table_schema text,
-- 	columns jsonb,
-- 	settings jsonb,
-- 	primary_key_column text,
-- 	CONSTRAINT table_view_pk PRIMARY KEY (table_view_id)
-- 
-- );
-- -- ddl-end --
-- 
-- object: grape.auto_scheduler | type: TABLE --
-- DROP TABLE IF EXISTS grape.auto_scheduler CASCADE;
CREATE TABLE grape.auto_scheduler(
	auto_scheduler_id serial NOT NULL,
	process_id integer,
	scheduled_interval interval,
	dow varchar(7) DEFAULT '1111111',
	days_of_month text DEFAULT '*',
	day_time time,
	run_as_user_id integer,
	run_with_params json,
	active boolean DEFAULT TRUE,
	CONSTRAINT auto_scheduler_pk PRIMARY KEY (auto_scheduler_id)

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
-- ddl-end --

-- object: proc_pg_function_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.proc_pg_function_idx CASCADE;
CREATE INDEX proc_pg_function_idx ON grape.process
	USING btree
	(
	  pg_function
	);
-- ddl-end --

-- object: grape.list_query_whitelist | type: TABLE --
-- DROP TABLE IF EXISTS grape.list_query_whitelist CASCADE;
CREATE TABLE grape.list_query_whitelist(
	schema text NOT NULL,
	tablename text NOT NULL,
	roles text[],
	CONSTRAINT list_query_whitelist_pk PRIMARY KEY (schema,tablename)

);
-- ddl-end --

-- object: auto_scheduler_process_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.auto_scheduler_process_idx CASCADE;
CREATE INDEX auto_scheduler_process_idx ON grape.auto_scheduler
	USING btree
	(
	  process_id
	);
-- ddl-end --

-- object: grape.setting_history | type: TABLE --
-- DROP TABLE IF EXISTS grape.setting_history CASCADE;
CREATE TABLE grape.setting_history(
	setting_history_id serial NOT NULL,
	setting_name text,
	value text,
	json_value json,
	date_inserted timestamptz,
	user_id integer,
	CONSTRAINT setting_history_pk PRIMARY KEY (setting_history_id)

);
-- ddl-end --

-- object: sch_status_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.sch_status_idx CASCADE;
CREATE INDEX sch_status_idx ON grape.schedule
	USING btree
	(
	  status
	);
-- ddl-end --

-- object: data_import_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_idx CASCADE;
CREATE INDEX data_import_idx ON grape.data_import
	USING btree
	(
	  data_import_id
	);
-- ddl-end --

-- object: data_import_filename_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_filename_idx CASCADE;
CREATE INDEX data_import_filename_idx ON grape.data_import
	USING btree
	(
	  filename
	);
-- ddl-end --

-- object: data_import_inserted_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_inserted_idx CASCADE;
CREATE INDEX data_import_inserted_idx ON grape.data_import
	USING btree
	(
	  date_inserted
	);
-- ddl-end --

-- object: data_import_process_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_process_idx CASCADE;
CREATE INDEX data_import_process_idx ON grape.data_import
	USING btree
	(
	  processing_function
	);
-- ddl-end --

-- object: data_import_user_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_user_idx CASCADE;
CREATE INDEX data_import_user_idx ON grape.data_import
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: data_import_row_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_row_idx CASCADE;
CREATE INDEX data_import_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_row_id
	);
-- ddl-end --

-- object: data_import_id_row_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.data_import_id_row_idx CASCADE;
CREATE INDEX data_import_id_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_id
	);
-- ddl-end --

-- object: grape.test_table | type: TABLE --
-- DROP TABLE IF EXISTS grape.test_table CASCADE;
CREATE TABLE grape.test_table(
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
-- ddl-end --

-- object: test_table_id_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.test_table_id_idx CASCADE;
CREATE INDEX test_table_id_idx ON grape.data_import
	USING btree
	(
	  test_table_id
	);
-- ddl-end --

-- object: test_table_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.test_table_idx CASCADE;
CREATE INDEX test_table_idx ON grape.test_table
	USING btree
	(
	  test_table_id
	);
-- ddl-end --

-- object: test_table_user_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.test_table_user_idx CASCADE;
CREATE INDEX test_table_user_idx ON grape.test_table
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: test_table_created_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.test_table_created_idx CASCADE;
CREATE INDEX test_table_created_idx ON grape.test_table
	USING btree
	(
	  date_created
	);
-- ddl-end --

-- object: test_table_updated | type: INDEX --
-- DROP INDEX IF EXISTS grape.test_table_updated CASCADE;
CREATE INDEX test_table_updated ON grape.test_table
	USING btree
	(
	  date_updated
	);
-- ddl-end --

-- -- object: grape.document_store | type: TABLE --
-- -- DROP TABLE IF EXISTS grape.document_store CASCADE;
-- CREATE TABLE grape.document_store(
-- 	document_store_id serial NOT NULL,
-- 	description text,
-- 	location text,
-- 	is_local boolean,
-- 	lookup_seq smallint DEFAULT 99,
-- 	insert_seq smallint DEFAULT 99,
-- 	CONSTRAINT document_store_pk PRIMARY KEY (document_store_id)
-- 
-- );
-- -- ddl-end --
-- COMMENT ON COLUMN grape.document_store.location IS 'Location within a document store (relative to the document store path)';
-- -- ddl-end --
-- 
-- -- object: grape.document | type: TABLE --
-- -- DROP TABLE IF EXISTS grape.document CASCADE;
-- CREATE TABLE grape.document(
-- 	document_id serial NOT NULL,
-- 	filename text,
-- 	location text,
-- 	document_guid uuid,
-- 	hash text,
-- 	date_inserted timestamptz DEFAULT NOW(),
-- 	user_id integer,
-- 	document_type text,
-- 	related_entity_id integer,
-- 	file_size integer,
-- 	mime_type text,
-- 	CONSTRAINT document_pk PRIMARY KEY (document_id)
-- 
-- );
-- -- ddl-end --
-- COMMENT ON COLUMN grape.document.location IS 'Location within a document store (relative to the document store path)';
-- -- ddl-end --
-- 
-- -- object: grape.document_store_document | type: TABLE --
-- -- DROP TABLE IF EXISTS grape.document_store_document CASCADE;
-- CREATE TABLE grape.document_store_document(
-- 	document_id integer NOT NULL,
-- 	document_store_id integer NOT NULL,
-- 	last_seen timestamptz,
-- 	CONSTRAINT document_store_document_pk PRIMARY KEY (document_id,document_store_id)
-- 
-- );
-- -- ddl-end --
-- 
-- object: grape.table_operation_whitelist | type: TABLE --
-- DROP TABLE IF EXISTS grape.table_operation_whitelist CASCADE;
CREATE TABLE grape.table_operation_whitelist(
	schema text NOT NULL,
	tablename text NOT NULL,
	allowed_operation text NOT NULL,
	roles text[],
	CONSTRAINT insert_query_pk PRIMARY KEY (schema,tablename,allowed_operation)

);
-- ddl-end --

-- object: grape.process_role | type: TABLE --
-- DROP TABLE IF EXISTS grape.process_role CASCADE;
CREATE TABLE grape.process_role(
	process_role_id serial NOT NULL,
	process_id integer,
	role_name text,
	can_view boolean DEFAULT TRUE,
	can_execute boolean DEFAULT FALSE,
	can_edit boolean DEFAULT FALSE,
	CONSTRAINT process_role_pk PRIMARY KEY (process_role_id)

);
-- ddl-end --

-- object: pr_process_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.pr_process_idx CASCADE;
CREATE INDEX pr_process_idx ON grape.process_role
	USING btree
	(
	  process_id
	);
-- ddl-end --

-- object: pr_role_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.pr_role_idx CASCADE;
CREATE INDEX pr_role_idx ON grape.process_role
	USING btree
	(
	  role_name
	);
-- ddl-end --

-- object: grape.user_network | type: TABLE --
-- DROP TABLE IF EXISTS grape.user_network CASCADE;
CREATE TABLE grape.user_network(
	user_network_id serial NOT NULL,
	user_id integer,
	network_id integer,
	CONSTRAINT whitelist_user_ip_pk PRIMARY KEY (user_network_id)

);
-- ddl-end --

-- object: un_user_id_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.un_user_id_idx CASCADE;
CREATE INDEX un_user_id_idx ON grape.user_network
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: grape.network | type: TABLE --
-- DROP TABLE IF EXISTS grape.network CASCADE;
CREATE TABLE grape.network(
	network_id serial NOT NULL,
	description text,
	address inet,
	CONSTRAINT network_pk PRIMARY KEY (network_id)

);
-- ddl-end --

-- object: un_network_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.un_network_idx CASCADE;
CREATE INDEX un_network_idx ON grape.user_network
	USING btree
	(
	  network_id
	);
-- ddl-end --

-- object: grape.report_template | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_template CASCADE;
CREATE TABLE grape.report_template(
	report_template_id serial NOT NULL,
	report_id integer,
	description text,
	params json,
	CONSTRAINT report_template_pk PRIMARY KEY (report_template_id),
	CONSTRAINT report_template_uq UNIQUE (report_template_id,report_id)

);
-- ddl-end --

-- object: rt_report_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.rt_report_idx CASCADE;
CREATE INDEX rt_report_idx ON grape.report_template
	USING btree
	(
	  report_id
	);
-- ddl-end --

-- object: grape.report_output | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_output CASCADE;
CREATE TABLE grape.report_output(
	report_output_id serial NOT NULL,
	report_output_type_id integer,
	description text,
	params json,
	CONSTRAINT report_output_pk PRIMARY KEY (report_output_id)

);
-- ddl-end --
COMMENT ON TABLE grape.report_output IS 'Parameters passed on to the output function';
-- ddl-end --
COMMENT ON COLUMN grape.report_output.params IS 'with';
-- ddl-end --

-- object: grape.report_output_type | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_output_type CASCADE;
CREATE TABLE grape.report_output_type(
	report_output_type_id serial NOT NULL,
	description text,
	ui_params json,
	function_name text,
	function_schema text,
	CONSTRAINT report_output_type_pk PRIMARY KEY (report_output_type_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.report_output_type.ui_params IS 'Params to build the GUI ';
-- ddl-end --

-- object: grape.report_result | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_result CASCADE;
CREATE TABLE grape.report_result(
	report_result_id serial NOT NULL,
	reports_executed_id integer,
	text_result text,
	row_result jsonb,
	result_table_name text,
	result_table_schema text,
	CONSTRAINT reports_executed_result_pk PRIMARY KEY (report_result_id),
	CONSTRAINT report_result_uq UNIQUE (report_result_id,reports_executed_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.report_result.text_result IS 'Used when the report''s output_type is TEXT';
-- ddl-end --
COMMENT ON COLUMN grape.report_result.row_result IS 'Used when the report''s output_type is ROW';
-- ddl-end --

-- object: grape.report_result_output | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_result_output CASCADE;
CREATE TABLE grape.report_result_output(
	report_result_output_id serial NOT NULL,
	report_result_id integer,
	report_output_id integer,
	reports_executed_id integer,
	CONSTRAINT report_result_output_pk PRIMARY KEY (report_result_output_id)

);
-- ddl-end --

-- object: grape.report_template_output | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_template_output CASCADE;
CREATE TABLE grape.report_template_output(
	report_template_output_id serial NOT NULL,
	report_template_id integer,
	report_output_id integer,
	CONSTRAINT report_template_output_pk PRIMARY KEY (report_template_output_id)

);
-- ddl-end --

-- object: grape.report_role | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_role CASCADE;
CREATE TABLE grape.report_role(
	report_role_id serial NOT NULL,
	report_id integer,
	role_name text,
	can_view boolean DEFAULT FALSE,
	can_edit boolean DEFAULT FALSE,
	can_execute boolean,
	CONSTRAINT report_role_pk PRIMARY KEY (report_role_id)

);
-- ddl-end --

-- object: grape.report_category | type: TABLE --
-- DROP TABLE IF EXISTS grape.report_category CASCADE;
CREATE TABLE grape.report_category(
	report_category_id serial NOT NULL,
	report_category text,
	CONSTRAINT report_category_pk PRIMARY KEY (report_category_id)

);
-- ddl-end --

-- -- object: grape.deployment | type: TABLE --
-- -- DROP TABLE IF EXISTS grape.deployment CASCADE;
-- CREATE TABLE grape.deployment(
-- 	deployment_id serial,
-- 	name text,
-- 	date_inserted timestamptz
-- );
-- -- ddl-end --
-- 
-- object: n_address_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.n_address_idx CASCADE;
CREATE INDEX n_address_idx ON grape.network
	USING btree
	(
	  address
	);
-- ddl-end --

-- object: grape.notification_function | type: TABLE --
-- DROP TABLE IF EXISTS grape.notification_function CASCADE;
CREATE TABLE grape.notification_function(
	notification_function_id serial NOT NULL,
	description text,
	function_name text,
	function_schema text,
	active boolean,
	emitted_event_name text,
	CONSTRAINT notification_function_pk PRIMARY KEY (notification_function_id)

);
-- ddl-end --

-- object: uh_user_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.uh_user_idx CASCADE;
CREATE INDEX uh_user_idx ON grape.user_history
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: sh_user_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.sh_user_idx CASCADE;
CREATE INDEX sh_user_idx ON grape.session_history
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: s_user_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.s_user_idx CASCADE;
CREATE INDEX s_user_idx ON grape.session
	USING btree
	(
	  user_id
	);
-- ddl-end --

-- object: grape.authentication_token | type: TABLE --
-- DROP TABLE IF EXISTS grape.authentication_token CASCADE;
CREATE TABLE grape.authentication_token(

);
-- ddl-end --

-- object: nf_active_idx | type: INDEX --
-- DROP INDEX IF EXISTS grape.nf_active_idx CASCADE;
CREATE INDEX nf_active_idx ON grape.notification_function
	USING btree
	(
	  active
	);
-- ddl-end --

-- object: grape.service | type: TABLE --
-- DROP TABLE IF EXISTS grape.service CASCADE;
CREATE TABLE grape.service(
	service_id serial NOT NULL,
	service_name text,
	shared_secret text,
	CONSTRAINT service_pk PRIMARY KEY (service_id)

);
-- ddl-end --
COMMENT ON TABLE grape.service IS 'This table is used for the generation of service tickets';
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

-- object: test_table_id_fk | type: CONSTRAINT --
-- ALTER TABLE grape.data_import DROP CONSTRAINT IF EXISTS test_table_id_fk CASCADE;
ALTER TABLE grape.data_import ADD CONSTRAINT test_table_id_fk FOREIGN KEY (test_table_id)
REFERENCES grape.test_table (test_table_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: data_import_fk | type: CONSTRAINT --
-- ALTER TABLE grape.data_import_row DROP CONSTRAINT IF EXISTS data_import_fk CASCADE;
ALTER TABLE grape.data_import_row ADD CONSTRAINT data_import_fk FOREIGN KEY (data_import_id)
REFERENCES grape.data_import (data_import_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: r_report_category_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report DROP CONSTRAINT IF EXISTS r_report_category_fk CASCADE;
ALTER TABLE grape.report ADD CONSTRAINT r_report_category_fk FOREIGN KEY (report_category_id)
REFERENCES grape.report_category (report_category_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: re_reports_fk | type: CONSTRAINT --
-- ALTER TABLE grape.reports_executed DROP CONSTRAINT IF EXISTS re_reports_fk CASCADE;
ALTER TABLE grape.reports_executed ADD CONSTRAINT re_reports_fk FOREIGN KEY (report_id)
REFERENCES grape.report (report_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: re_report_template_fk | type: CONSTRAINT --
-- ALTER TABLE grape.reports_executed DROP CONSTRAINT IF EXISTS re_report_template_fk CASCADE;
ALTER TABLE grape.reports_executed ADD CONSTRAINT re_report_template_fk FOREIGN KEY (report_template_id,report_id)
REFERENCES grape.report_template (report_template_id,report_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: session_user_fk | type: CONSTRAINT --
-- ALTER TABLE grape.session_history DROP CONSTRAINT IF EXISTS session_user_fk CASCADE;
ALTER TABLE grape.session_history ADD CONSTRAINT session_user_fk FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: as_process_fk | type: CONSTRAINT --
-- ALTER TABLE grape.auto_scheduler DROP CONSTRAINT IF EXISTS as_process_fk CASCADE;
ALTER TABLE grape.auto_scheduler ADD CONSTRAINT as_process_fk FOREIGN KEY (process_id)
REFERENCES grape.process (process_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: setting_name_fk | type: CONSTRAINT --
-- ALTER TABLE grape.setting_history DROP CONSTRAINT IF EXISTS setting_name_fk CASCADE;
ALTER TABLE grape.setting_history ADD CONSTRAINT setting_name_fk FOREIGN KEY (setting_name)
REFERENCES grape.setting (name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- -- object: document_store_fk | type: CONSTRAINT --
-- -- ALTER TABLE grape.document_store_document DROP CONSTRAINT IF EXISTS document_store_fk CASCADE;
-- ALTER TABLE grape.document_store_document ADD CONSTRAINT document_store_fk FOREIGN KEY (document_store_id)
-- REFERENCES grape.document_store (document_store_id) MATCH FULL
-- ON DELETE NO ACTION ON UPDATE NO ACTION;
-- -- ddl-end --
-- 
-- -- object: document_fk | type: CONSTRAINT --
-- -- ALTER TABLE grape.document_store_document DROP CONSTRAINT IF EXISTS document_fk CASCADE;
-- ALTER TABLE grape.document_store_document ADD CONSTRAINT document_fk FOREIGN KEY (document_id)
-- REFERENCES grape.document (document_id) MATCH FULL
-- ON DELETE NO ACTION ON UPDATE NO ACTION;
-- -- ddl-end --
-- 
-- object: process_fk | type: CONSTRAINT --
-- ALTER TABLE grape.process_role DROP CONSTRAINT IF EXISTS process_fk CASCADE;
ALTER TABLE grape.process_role ADD CONSTRAINT process_fk FOREIGN KEY (process_id)
REFERENCES grape.process (process_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: user_fk | type: CONSTRAINT --
-- ALTER TABLE grape.user_network DROP CONSTRAINT IF EXISTS user_fk CASCADE;
ALTER TABLE grape.user_network ADD CONSTRAINT user_fk FOREIGN KEY (user_id)
REFERENCES grape."user" (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: network_fk | type: CONSTRAINT --
-- ALTER TABLE grape.user_network DROP CONSTRAINT IF EXISTS network_fk CASCADE;
ALTER TABLE grape.user_network ADD CONSTRAINT network_fk FOREIGN KEY (network_id)
REFERENCES grape.network (network_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: report_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_template DROP CONSTRAINT IF EXISTS report_fk CASCADE;
ALTER TABLE grape.report_template ADD CONSTRAINT report_fk FOREIGN KEY (report_id)
REFERENCES grape.report (report_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: ro_report_output_type_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_output DROP CONSTRAINT IF EXISTS ro_report_output_type_fk CASCADE;
ALTER TABLE grape.report_output ADD CONSTRAINT ro_report_output_type_fk FOREIGN KEY (report_output_type_id)
REFERENCES grape.report_output_type (report_output_type_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: reports_executed_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_result DROP CONSTRAINT IF EXISTS reports_executed_fk CASCADE;
ALTER TABLE grape.report_result ADD CONSTRAINT reports_executed_fk FOREIGN KEY (reports_executed_id)
REFERENCES grape.reports_executed (reports_executed_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: report_result_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_result_output DROP CONSTRAINT IF EXISTS report_result_fk CASCADE;
ALTER TABLE grape.report_result_output ADD CONSTRAINT report_result_fk FOREIGN KEY (report_result_id,reports_executed_id)
REFERENCES grape.report_result (report_result_id,reports_executed_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: reo_report_output_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_result_output DROP CONSTRAINT IF EXISTS reo_report_output_fk CASCADE;
ALTER TABLE grape.report_result_output ADD CONSTRAINT reo_report_output_fk FOREIGN KEY (report_output_id)
REFERENCES grape.report_output (report_output_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: report_template_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_template_output DROP CONSTRAINT IF EXISTS report_template_fk CASCADE;
ALTER TABLE grape.report_template_output ADD CONSTRAINT report_template_fk FOREIGN KEY (report_template_id)
REFERENCES grape.report_template (report_template_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: rto_report_output_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_template_output DROP CONSTRAINT IF EXISTS rto_report_output_fk CASCADE;
ALTER TABLE grape.report_template_output ADD CONSTRAINT rto_report_output_fk FOREIGN KEY (report_output_id)
REFERENCES grape.report_output (report_output_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: rr_report_fk | type: CONSTRAINT --
-- ALTER TABLE grape.report_role DROP CONSTRAINT IF EXISTS rr_report_fk CASCADE;
ALTER TABLE grape.report_role ADD CONSTRAINT rr_report_fk FOREIGN KEY (report_id)
REFERENCES grape.report (report_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


