
DROP TABLE IF EXISTS grape.user_network ;
DROP TABLE IF EXISTS grape.network ;

CREATE TABLE grape.user_network(
	user_network_id serial NOT NULL,
	user_id integer,
	network_id integer,
	CONSTRAINT whitelist_user_ip_pk PRIMARY KEY (user_network_id)

);

CREATE INDEX un_user_id_idx ON grape.user_network
	USING btree
	(
	  user_id
	);
CREATE INDEX un_network_idx ON grape.user_network
	USING btree
	(
	  network_id
	);


CREATE TABLE grape.network(
	network_id serial NOT NULL,
	description text,
	address inet,
	CONSTRAINT network_pk PRIMARY KEY (network_id)

);
CREATE INDEX n_address_idx ON grape.network
	USING btree
	(
	  address
	);

ALTER TABLE grape.user_network ADD CONSTRAINT network_fk FOREIGN KEY (network_id)
	REFERENCES grape.network (network_id) MATCH FULL
	ON DELETE NO ACTION ON UPDATE NO ACTION;




