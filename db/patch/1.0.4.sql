
CREATE TABLE grape.table_operation_whitelist(
	schema text NOT NULL,
	tablename text NOT NULL,
	allowed_operation text NOT NULL,
	roles text[],
	CONSTRAINT insert_query_pk PRIMARY KEY (schema,tablename,allowed_operation)
);


