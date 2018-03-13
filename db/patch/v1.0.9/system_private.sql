

DROP TABLE IF EXISTS grape.system_private CASCADE;
CREATE TABLE grape.system_private(
	system_private_id serial NOT NULL,
	my_secret text,
	role text,
	last_reset timestamptz,
	CONSTRAINT system_private_pk PRIMARY KEY (system_private_id)

);

