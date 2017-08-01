
CREATE TABLE grape.notification_function(
	notification_function_id serial NOT NULL,
	description text,
	function_name text,
	function_schema text,
	active boolean,
	CONSTRAINT notification_function_pk PRIMARY KEY (notification_function_id)

);

