-- Database generated with pgModeler (PostgreSQL Database Modeler).
-- PostgreSQL version: 9.3
-- Project Site: pgmodeler.com.br
-- Model Author: ---

SET check_function_bodies = false;
-- ddl-end --


-- Database creation must be done outside an multicommand file.
-- These commands were put in this file only for convenience.
-- -- object: grape | type: DATABASE --
-- CREATE DATABASE grape
-- ;
-- -- ddl-end --
-- 

-- object: grape | type: SCHEMA --
CREATE SCHEMA grape;
-- ddl-end --

SET search_path TO pg_catalog,public,grape;
-- ddl-end --

-- object: hstore | type: EXTENSION --
CREATE EXTENSION hstore
      WITH SCHEMA public;
-- ddl-end --

-- object: grape.access_role | type: TABLE --
CREATE TABLE grape.access_role(
	role_name text,
	CONSTRAINT access_role_pk PRIMARY KEY (role_name)

);
-- ddl-end --
-- object: grape.user_role | type: TABLE --
CREATE TABLE grape.user_role(
	user_id integer,
	role_name text,
	CONSTRAINT user_role_pk PRIMARY KEY (user_id,role_name)

);
-- ddl-end --
-- object: grape.session | type: TABLE --
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
CREATE TABLE grape.access_path(
	role_name text,
	regex_path text,
	method text[] DEFAULT '{POST, PUT, GET}',
	CONSTRAINT access_path_pk PRIMARY KEY (role_name,regex_path,method)

);
-- ddl-end --
COMMENT ON COLUMN grape.access_path.method IS 'HTTP methods accepted by this path/route eg. (GET, POST, etc)';
-- ddl-end --
-- ddl-end --

-- object: grape.user_history | type: TABLE --
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
-- object: user_id_rel | type: CONSTRAINT --
ALTER TABLE grape.user_role ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --


-- object: role_name_rel | type: CONSTRAINT --
ALTER TABLE grape.user_role ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --


-- object: user_id_rel | type: CONSTRAINT --
ALTER TABLE grape.session ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --


-- object: role_name_rel | type: CONSTRAINT --
ALTER TABLE grape.access_path ADD CONSTRAINT role_name_rel FOREIGN KEY (role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --


-- object: user_id_rel | type: CONSTRAINT --
ALTER TABLE grape.user_history ADD CONSTRAINT user_id_rel FOREIGN KEY (user_id)
REFERENCES grape.user (user_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --
