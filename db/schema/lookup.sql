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

-- object: lookup | type: SCHEMA --
CREATE SCHEMA lookup;
-- ddl-end --

-- object: lookup_cp1 | type: SCHEMA --
CREATE SCHEMA lookup_cp1;
-- ddl-end --

SET search_path TO pg_catalog,public,lookup,lookup_cp1;
-- ddl-end --

-- object: lookup.bank_branch | type: TABLE --
CREATE TABLE lookup.bank_branch(
	bank_branch_id serial NOT NULL,
	branch_name text NOT NULL,
	branch_code text NOT NULL,
	bank_id integer NOT NULL,
	CONSTRAINT bank_branch_id_pk PRIMARY KEY (bank_branch_id)

);
-- ddl-end --
-- object: lookup.valid_bank_name | type: TABLE --
CREATE TABLE lookup.valid_bank_name(
	bank_id integer NOT NULL,
	bank_name text NOT NULL,
	universal_branch text,
	CONSTRAINT bank_id_pk PRIMARY KEY (bank_id)

);
-- ddl-end --
-- object: lookup.relationship | type: TABLE --
CREATE TABLE lookup.relationship(
	relationship_id integer,
	description text,
	CONSTRAINT relationship_id_pk PRIMARY KEY (relationship_id)

);
-- ddl-end --
-- object: bank_branch_bank_id_fk | type: CONSTRAINT --
ALTER TABLE lookup.bank_branch ADD CONSTRAINT bank_branch_bank_id_fk FOREIGN KEY (bank_id)
REFERENCES lookup.valid_bank_name (bank_id) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION NOT DEFERRABLE;
-- ddl-end --



