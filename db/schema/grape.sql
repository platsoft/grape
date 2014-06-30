-- Database generated with pgModeler (PostgreSQL Database Modeler).
-- pgModeler  version: 0.7.1
-- PostgreSQL version: 9.3
-- Project Site: pgmodeler.com.br
-- Model Author: ---

SET check_function_bodies = false;
-- ddl-end --


-- Database creation must be done outside an multicommand file.
-- These commands were put in this file only for convenience.
-- -- object: grape | type: DATABASE --
-- -- DROP DATABASE grape;
-- CREATE DATABASE grape
-- ;
-- -- ddl-end --
-- 

-- object: grape | type: SCHEMA --
-- DROP SCHEMA grape;
CREATE SCHEMA grape;
-- ddl-end --

-- object: proc | type: SCHEMA --
-- DROP SCHEMA proc;
CREATE SCHEMA proc;
-- ddl-end --

-- object: proc_cp | type: SCHEMA --
-- DROP SCHEMA proc_cp;
CREATE SCHEMA proc_cp;
-- ddl-end --

SET search_path TO pg_catalog,public,grape,proc,proc_cp;
-- ddl-end --

-- object: hstore | type: EXTENSION --
-- DROP EXTENSION hstore CASCADE;
CREATE EXTENSION hstore
      WITH SCHEMA public;
-- ddl-end --

-- object: grape.access_role | type: TABLE --
-- DROP TABLE grape.access_role;
CREATE TABLE grape.access_role(
	role_name text,
	CONSTRAINT access_role_pk PRIMARY KEY (role_name)

);
-- ddl-end --
-- object: grape.user_role | type: TABLE --
-- DROP TABLE grape.user_role;
CREATE TABLE grape.user_role(
	user_id integer,
	role_name text,
	CONSTRAINT user_role_pk PRIMARY KEY (user_id,role_name)

);
-- ddl-end --
-- object: grape.session | type: TABLE --
-- DROP TABLE grape.session;
CREATE TABLE grape.session(
	session_id text,
	ip_address text,
	user_id integer,
	date_inserted timestamp,
	last_activity timestamp,
	CONSTRAINT session_pk PRIMARY KEY (session_id)

);
-- ddl-end --
-- object: grape.access_path | type: TABLE --
-- DROP TABLE grape.access_path;
CREATE TABLE grape.access_path(
	role_name text,
	regex_path text,
	method text[] DEFAULT '{POST, PUT, GET}',
	CONSTRAINT access_path_pk PRIMARY KEY (role_name,regex_path,method)

);
-- ddl-end --
COMMENT ON COLUMN grape.access_path.method IS 'HTTP methods accepted by this path/route eg. (GET, POST, etc)';
-- ddl-end --

-- object: grape.user_history | type: TABLE --
-- DROP TABLE grape.user_history;
CREATE TABLE grape.user_history(
	user_history_id serial,
	user_id integer,
	date_inserted timestamp DEFAULT CURRENT_TIMESTAMP,
	data public.hstore,
	blame_id integer,
	CONSTRAINT user_history_id_pk PRIMARY KEY (user_history_id)

);
-- ddl-end --
-- object: grape.user | type: TABLE --
-- DROP TABLE grape.user;
CREATE TABLE grape.user(
	user_id serial,
	password text,
	username text,
	email text,
	fullnames text,
	active boolean DEFAULT true,
	external smallint DEFAULT 0,
	blame_id integer,
	CONSTRAINT user_pk PRIMARY KEY (user_id)

);
-- ddl-end --
-- object: grape.process | type: TABLE --
-- DROP TABLE grape.process;
CREATE TABLE grape.process(
	process_id serial,
	pg_function text,
	description text,
	param json,
	process_type text,
	CONSTRAINT process_pk PRIMARY KEY (process_id)

)WITH ( OIDS = TRUE );
-- ddl-end --
COMMENT ON COLUMN grape.process.process_type IS 'PG_FUNCTION; COMMAND';
-- ddl-end --

-- object: grape.e_schedule_status | type: TYPE --
-- DROP TYPE grape.e_schedule_status;
CREATE TYPE grape.e_schedule_status AS
 ENUM ('Running','Completed','Error','NewTask');
-- ddl-end --

-- object: grape.schedule_log | type: TABLE --
-- DROP TABLE grape.schedule_log;
CREATE TABLE grape.schedule_log(
	schedule_log_id serial,
	schedule_id integer,
	time timestamp,
	message text,
	CONSTRAINT schedule_log_pk PRIMARY KEY (schedule_log_id)

)WITH ( OIDS = TRUE );
-- ddl-end --
-- object: grape.schedule | type: TABLE --
-- DROP TABLE grape.schedule;
CREATE TABLE grape.schedule(
	schedule_id serial,
	process_id integer,
	time_sched timestamp,
	time_started timestamp,
	time_ended timestamp,
	pid integer,
	param json,
	user_id integer,
	status grape.e_schedule_status DEFAULT 'NewTask',
	CONSTRAINT schedule_pk PRIMARY KEY (schedule_id)

)WITH ( OIDS = TRUE );
-- ddl-end --
COMMENT ON COLUMN grape.schedule.time_sched IS 'Scheduled to start on';
COMMENT ON COLUMN grape.schedule.time_started IS 'Actual start';
-- ddl-end --

-- object: grape.data_import | type: TABLE --
-- DROP TABLE grape.data_import;
CREATE TABLE grape.data_import(
	data_import_id serial,
	filename text,
	date_inserted timestamp DEFAULT NOW(),
	parameter json,
	description text,
	CONSTRAINT data_import_pk PRIMARY KEY (data_import_id)

);
-- ddl-end --
-- object: grape.data_import_row | type: TABLE --
-- DROP TABLE grape.data_import_row;
CREATE TABLE grape.data_import_row(
	data_import_row_id serial,
	data_import_id integer,
	data json,
	CONSTRAINT data_import_row_pk PRIMARY KEY (data_import_row_id)

);
-- ddl-end --
-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_role DROP CONSTRAINT user_id_rel;
ALTER TABLE grape.user_role ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: role_name_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_role DROP CONSTRAINT role_name_rel;
ALTER TABLE grape.user_role ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.session DROP CONSTRAINT user_id_rel;
ALTER TABLE grape.session ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: role_name_rel | type: CONSTRAINT --
-- ALTER TABLE grape.access_path DROP CONSTRAINT role_name_rel;
ALTER TABLE grape.access_path ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: user_id_rel | type: CONSTRAINT --
-- ALTER TABLE grape.user_history DROP CONSTRAINT user_id_rel;
ALTER TABLE grape.user_history ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: schedule_fk | type: CONSTRAINT --
-- ALTER TABLE grape.schedule_log DROP CONSTRAINT schedule_fk;
ALTER TABLE grape.schedule_log ADD CONSTRAINT schedule_fk FOREIGN KEY (schedule_id)
REFERENCES grape.schedule (schedule_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: process_fk | type: CONSTRAINT --
-- ALTER TABLE grape.schedule DROP CONSTRAINT process_fk;
ALTER TABLE grape.schedule ADD CONSTRAINT process_fk FOREIGN KEY (process_id)
REFERENCES grape.process (process_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --


-- object: data_import_fk | type: CONSTRAINT --
-- ALTER TABLE grape.data_import_row DROP CONSTRAINT data_import_fk;
ALTER TABLE grape.data_import_row ADD CONSTRAINT data_import_fk FOREIGN KEY (data_import_id)
REFERENCES grape.data_import (data_import_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --



