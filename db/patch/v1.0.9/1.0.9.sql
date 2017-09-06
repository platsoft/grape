
SELECT grape.set_value('grape_version', '1.0.9');

INSERT INTO grape.access_role (role_name) VALUES ('pg_stat'); -- role that can view pg stats

SELECT grape.table_permissions_add('pg_catalog', 
	'{pg_stat_user_functions,'
	'pg_stat_activity,'
	'pg_stat_replication}'::TEXT[], 

	'pg_stat',
	'SELECT'
);


ALTER TABLE grape.notification_function ADD COLUMN emitted_event_name TEXT;
CREATE INDEX nf_active_idx ON grape.notification_function
	USING btree
	(
	  active
	);
CREATE TABLE grape.service(
	service_id serial NOT NULL,
	service_name text,
	shared_secret text,
	CONSTRAINT service_pk PRIMARY KEY (service_id)

);
-- ddl-end --
COMMENT ON TABLE grape.service IS 'This table is used for the generation of service tickets';
-- ddl-end --

ALTER TABLE grape.session ADD COLUMN session_origin TEXT;

ALTER TABLE grape.process DROP CONSTRAINT IF EXISTS "process_uq";


