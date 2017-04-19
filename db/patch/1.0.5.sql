

CREATE TABLE grape.process_role(
	process_role_id serial NOT NULL,
	process_id integer,
	role_name text,
	can_view boolean DEFAULT TRUE,
	can_execute boolean DEFAULT FALSE,
	can_edit boolean DEFAULT FALSE,
	CONSTRAINT process_role_pk PRIMARY KEY (process_role_id)

);

CREATE INDEX pr_process_idx ON grape.process_role
	USING btree
	(
	  process_id
	);

CREATE INDEX pr_role_idx ON grape.process_role
	USING btree
	(
	  role_name
	);


