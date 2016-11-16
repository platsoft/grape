BEGIN;

CREATE TABLE IF NOT EXISTS grape.test_table(
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

ALTER TABLE grape.data_import
	ALTER COLUMN date_inserted TYPE timestamptz,
	ALTER COLUMN date_inserted SET DEFAULT NOW(),
	ALTER COLUMN date_done TYPE timestamptz,
	ADD COLUMN user_id integer,
	ADD COLUMN data_processed tstzrange,
	ADD COLUMN test_table_id integer;

ALTER TABLE grape.data_import 
	ADD CONSTRAINT test_table_id_fk FOREIGN KEY (test_table_id)
		REFERENCES grape.test_table (test_table_id) MATCH FULL
		ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE grape.data_import_type
	DROP COLUMN full_description text,
	ADD COLUMN short_description text,
	ADD COLUMN param_definition json;

-- DROP INDEX IF EXISTS grape.data_import_idx CASCADE;
CREATE INDEX data_import_idx ON grape.data_import
	USING btree
	(
	  data_import_id
	);

-- DROP INDEX IF EXISTS grape.data_import_filename_idx CASCADE;
CREATE INDEX data_import_filename_idx ON grape.data_import
	USING btree
	(
	  filename
	);

-- DROP INDEX IF EXISTS grape.data_import_inserted_idx CASCADE;
CREATE INDEX data_import_inserted_idx ON grape.data_import
	USING btree
	(
	  date_inserted
	);

-- DROP INDEX IF EXISTS grape.data_import_process_idx CASCADE;
CREATE INDEX data_import_process_idx ON grape.data_import
	USING btree
	(
	  processing_function
	);

-- DROP INDEX IF EXISTS grape.data_import_user_idx CASCADE;
CREATE INDEX data_import_user_idx ON grape.data_import
	USING btree
	(
	  user_id
	);

-- DROP INDEX IF EXISTS grape.data_import_row_idx CASCADE;
CREATE INDEX data_import_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_row_id
	);

-- DROP INDEX IF EXISTS grape.data_import_id_row_idx CASCADE;
CREATE INDEX data_import_id_row_idx ON grape.data_import_row
	USING btree
	(
	  data_import_id
	);

-- DROP INDEX IF EXISTS grape.test_table_id_idx CASCADE;
CREATE INDEX test_table_id_idx ON grape.data_import
	USING btree
	(
	  test_table_id
	);

-- DROP INDEX IF EXISTS grape.test_table_idx CASCADE;
CREATE INDEX test_table_idx ON grape.test_table
	USING btree
	(
	  test_table_id
	);

-- DROP INDEX IF EXISTS grape.test_table_user_idx CASCADE;
CREATE INDEX test_table_user_idx ON grape.test_table
	USING btree
	(
	  user_id
	);

-- DROP INDEX IF EXISTS grape.test_table_created_idx CASCADE;
CREATE INDEX test_table_created_idx ON grape.test_table
	USING btree
	(
	  date_created
	);

-- DROP INDEX IF EXISTS grape.test_table_updated CASCADE;
CREATE INDEX test_table_updated ON grape.test_table
	USING btree
	(
	  date_updated
	);


-- v_test_table view
CREATE OR REPLACE VIEW grape.v_test_table AS
	SELECT 
		test_table_id,
		table_schema,
		table_name,
		description,
		date_created,
		user_id,
		date_updated,
		grape.username(user_id) AS username
	FROM grape.test_table;

--recreate changed functions
-- data_import functions
/**
 * upsert data import types
 */
CREATE OR REPLACE FUNCTION grape.upsert_data_import_type(
	_processing_function TEXT, 
	_short_description TEXT, 
	_file_format_info TEXT, 
	_function_schema TEXT, 
	_param_definition JSON DEFAULT NULL) RETURNS VOID AS $$
	INSERT INTO grape.data_import_type (
		processing_function, 
		short_description, 
		file_format_info, 
		function_schema, 
		param_definition) 
	VALUES (
		_processing_function, 
		_short_description, 
		_file_format_info, 
		_function_schema, 
		_param_definition)
	ON CONFLICT (processing_function) --if processing_function name is the same updatre all the other values 
	DO UPDATE SET short_description=EXCLUDED.short_description,
		file_format_info=EXCLUDED.file_format_info, 
		function_schema=EXCLUDED.function_schema,
		param_definition=EXCLUDED.param_definition;
$$ LANGUAGE sql;

/*
 * overloaded function estimate potential datatype of a text value
 */
CREATE OR REPLACE FUNCTION grape.estimate_datatype(TEXT) RETURNS TEXT AS $$
DECLARE
	_data_type TEXT := 'TEXT';
	_value TEXT;
BEGIN
	_value := trim($1);--remove leading and trailing whitespace which simplifies and focuses regex
	IF _value ~ '^$' THEN
		_data_type := 'NULL';
	ELSIF _value ~ '^\d+$' THEN
		_data_type := 'INTEGER';
	ELSIF _value ~ '^\d+\.\d+$' THEN
		_data_type := 'NUMERIC';
	ELSIF _value ~ '^\d{4}-\d{2}-\d{2}$' THEN
		_data_type := 'DATE';
	ELSIF _value ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}$' THEN
		_data_type := 'TIMESTAMP';
	ELSIF _value ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}\+\d{2}$' THEN
		_data_type := 'TIMESTAMPTZ';
	END IF;

	RETURN _data_type;
END; $$ LANGUAGE plpgsql;

/**
 * overloaded function estimate potential datatype of text array
 */
CREATE OR REPLACE FUNCTION grape.estimate_datatype(TEXT[]) RETURNS TEXT AS $$
DECLARE
	_previous_data_type TEXT;
	_data_type TEXT := 'TEXT';
	_value TEXT;
	_rec RECORD;
BEGIN
	--loop through array of values to do datatype tests on
	FOREACH _value IN ARRAY $1 LOOP 
		_data_type := grape.estimate_datatype(_value);
		
		--give _previous_datatype a value if it is null
		IF _previous_data_type IS NULL THEN
			_previous_data_type := _data_type;
		END IF;

		--if multiple datatypes are suggested or all values are null then defualt to TEXT and exit loop
		IF _data_type != 'NULL' AND _previous_data_type != 'NULL' AND _data_type != _previous_data_type THEN
			_data_type := 'TEXT';
			EXIT;
		END IF;

		--use previous datatype if current datatype is NULL
		IF _data_type = 'NULL' THEN
			_data_type := _previous_data_type;
		ELSE
			_previous_data_type := _data_type;
		END IF;

	END LOOP;

	--if all values are null default to TEXT
	IF _data_type = 'NULL' THEN
		_data_type := 'TEXT';
	END IF;

	RETURN _data_type;
END; $$ LANGUAGE plpgsql;

/**
 * api function to insert a data_import entry
 * 
 */
CREATE OR REPLACE FUNCTION grape.data_import_insert(JSON) RETURNS JSON AS $$
DECLARE
	_filename TEXT;
	_description TEXT;
	_data_import_id INTEGER;

	_schema TEXT;
	_tablename TEXT;
	_idxname TEXT;
	_processing_param JSON;

	_processing_function TEXT;
BEGIN
	_filename := $1->>'filename';
	_description := $1->>'description';
	_processing_param := $1->'processing_param';

	IF json_extract_path($1, 'processing_function') IS NOT NULL THEN
		_processing_function := $1->>'processing_function';
	END IF;

	INSERT INTO grape.data_import (filename, description, parameter, date_done, record_count, valid_record_count, processing_function, processing_param, data_import_status, user_id) 
		VALUES (_filename, _description, $1, NULL, 0, 0, _processing_function, _processing_param, 0, current_user_id()) 
		RETURNING data_import_id INTO _data_import_id;
	
	_schema := grape.setting('data_import_schema', 'grape');
	_tablename := FORMAT('data_import_%s', _data_import_id);
	_idxname := FORMAT('%s_data_import_row_idx', _tablename);

	--create a "copy" of data_import_row table with indexes and populate it with the data imported
	EXECUTE FORMAT('CREATE TABLE "%s"."%s" () INHERITS (grape.data_import_row)', _schema, _tablename);
	EXECUTE FORMAT('CREATE INDEX "%s" ON "%s"."%s" (data_import_row_id)', _idxname, _schema, _tablename);

	UPDATE grape.data_import SET 
		result_table=_tablename, 
		result_schema=_schema 
	WHERE 
		data_import_id=_data_import_id::INTEGER;

	RETURN grape.api_success('data_import_id', _data_import_id);
END; $$ LANGUAGE plpgsql;

/**
 * api function to delete a data_import entry
 * 
 */
CREATE OR REPLACE FUNCTION grape.data_import_delete(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_schema TEXT;
	_tablename TEXT;
	_data_import_status INTEGER;
	_test_table_id INTEGER;
BEGIN
	_data_import_id := $1->>'data_import_id';

	IF _data_import_id IS NULL THEN
		RETURN grape.api_error('data_import_id was not provided', -3);
	END IF;

	SELECT result_schema, result_table, data_import_status, test_table_id  
	INTO _schema, _tablename, _data_import_status, _test_table_id
	FROM grape.data_import
	WHERE data_import_id=_data_import_id::INTEGER ;

	--delete only if table can be found and non of the rows for the data_import has been proccessed
	IF _tablename IS NULL THEN
		RETURN grape.api_error(FORMAT('Could not find data_import_id: %s', _data_import_id), -5);
	ELSIF _data_import_status > 1 THEN
		RETURN grape.api_error('Cannot delete this as some or all of its data has been processed', -2);
	ELSIF _test_table_id IS NOT NULL THEN
		RETURN grape.api_error('Cannot delete this as its data is used in a test table',-2);
	END IF;

	EXECUTE FORMAT('DROP TABLE "%s"."%s"', _schema, _tablename);

	DELETE FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER; 

	RETURN grape.api_success();

END; $$ LANGUAGE plpgsql;

/**
 * Api Function to insert a row of JSON into data_import_row
 * Required field data_import_id must be in the JSON data
 */
CREATE OR REPLACE FUNCTION grape.data_import_row_insert(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_schema TEXT;
	_tablename TEXT;
	_data JSONB;
BEGIN
	_data := ($1->>'data')::JSONB;
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	SELECT result_table, result_schema INTO _tablename, _schema FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;

	EXECUTE FORMAT ('INSERT INTO "%s"."%s" (data_import_id, data) VALUES ($1, $2)', _schema, _tablename) USING _data_import_id, _data::JSON;
	
	UPDATE grape.data_import SET record_count = record_count+1 WHERE data_import_id=_data_import_id::INTEGER;

	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;

/**
 * api function to notify server that insertion of all the rows has been completed and timestamp this completion
 * 
 */
CREATE OR REPLACE FUNCTION grape.data_import_done(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	UPDATE grape.data_import SET date_done=CURRENT_TIMESTAMP, data_import_status=1 WHERE data_import_id=_data_import_id::INTEGER;
	
	RETURN grape.api_success('data_import_id', _data_import_id);
END; $$ LANGUAGE plpgsql;

/**
 * Internal function to Process data import data
 */
CREATE OR REPLACE FUNCTION grape.data_import_process(_data_import_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_data_import grape.data_import;

	_function_schema TEXT;
	_data_import_row_id INTEGER;
	_data_import_status INTEGER;

	_data JSON;
	_args JSONB := '{}';
	_result JSON;
	_start_timestamp TIMESTAMPTZ;
	_shared_data JSON := '{}';
	_index INTEGER := 0;
BEGIN
	SELECT data_import.* 
	INTO _data_import
	FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;
	
	SELECT function_schema INTO _function_schema FROM grape.data_import_type WHERE processing_function=_data_import.processing_function::TEXT;

	_start_timestamp := CURRENT_TIMESTAMP;

	_data_import_status := 4;

	--loop throuugh the data_import_rows and attempt to process the data
	FOR _data_import_row_id, _data IN EXECUTE FORMAT('SELECT data_import_row_id, data::JSONB FROM "%s"."%s" WHERE processed=FALSE', _data_import.result_schema, _data_import.result_table) LOOP
		--add some additional data that is passed to the process function to make it more aware of it position and allow for the option
		--to share data between different sequential processes
		_index := _index + 1;
		_args := _args || jsonb_build_object('index', _index, 'data_import_row_id', _data_import_row_id,'data', _data, 'shared_data',_shared_data);
		EXECUTE FORMAT ('SELECT "%s"."%s" ($1, $2)', _function_schema, _data_import.processing_function) USING _data_import, _args INTO _result;
		EXECUTE FORMAT ('UPDATE "%s"."%s" SET processed=TRUE, result=$1 WHERE data_import_row_id=$2', _data_import.result_schema, _data_import.result_table) USING _result->'result', _data_import_row_id;
		_shared_data := _result->'shared_data'; 
		IF _result->'result'->>'status'='OK' THEN
			UPDATE grape.data_import SET valid_record_count=valid_record_count+1 WHERE data_import_id=_data_import_id::INTEGER;
		ELSE
			_data_import_status := 3;
		END IF;
	END LOOP;

	UPDATE grape.data_import 
	SET data_processed=tstzrange(_start_timestamp, CURRENT_TIMESTAMP), 
		data_import_status=_data_import_status 
	WHERE data_import_id=_data_import_id::INTEGER;

	--TODO return more useful data
	RETURN 1;
END; $$ LANGUAGE plpgsql;

/**
 * Api function to Process data import data, calls internal process function
 */
CREATE OR REPLACE FUNCTION grape.data_import_process(JSON) RETURNS JSON AS $$
DECLARE
	_return_code INTEGER;
	_data_import_id INTEGER;
	_info JSON;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;
	
	IF _data_import_id IS NULL THEN
		RETURN grape.api_error('data_import_id not provided', -3);
	END IF;

	_return_code := grape.data_import_process(_data_import_id);

	--TODO look at improving return data structures
	--coalate some useful information to return to api call
	IF _return_code = 1 THEN
		SELECT json_build_object('data_import_status', data_import_status,
								'record_count', record_count,
								'valid_record_count', valid_record_count)
		INTO _info
		FROM grape.data_import
		WHERE data_import_id = _data_import_id::INTEGER;
		
		RETURN grape.api_success(_info);
	ELSE
		RETURN grape.api_error('data_import_process failed', -1);
	END IF;
END; $$ LANGUAGE plpgsql;

/**
 * Api function to create a test table from a data imports data
 */
CREATE OR REPLACE FUNCTION grape.data_import_test_table_insert(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_test_table_spec JSON;
	_result_table TEXT;
	_result_schema TEXT;
	_test_table_name TEXT;
	_test_table_schema TEXT;
	_columns JSON;
	_values JSON;
	_test_table_id INTEGER;
	_description TEXT;
	_row JSONB;
	_rows JSONB;
	_data JSONB;
	_key TEXT;
	_append TEXT;
	_result JSON;
BEGIN
	--TODO make sure data import id exists
	_data_import_id := ($1->>'data_import_id')::INTEGER;
	_test_table_name := $1->>'table_name';
	_description := $1->>'description';
	_append := $1->>'append';

	SELECT result_table, result_schema, test_table_id
	INTO _result_table, _result_schema, _test_table_id
	FROM grape.data_import 
	WHERE data_import_id = _data_import_id::INTEGER;

	IF _test_table_id IS NOT NULL AND _append IS NULL THEN
		RETURN grape.api_error('Can not create Table as it already exists, maybe you meant to append to the table instead?', -1);
	ELSEIF _test_table_id IS NOT NULL AND _append IS NOT NULL THEN
		RETURN grape.api_error('Can not append as this data_import has already been appended to a test table', -1); 
	ELSEIF _test_table_id IS NULL AND _append IS NOT NULL THEN
		_test_table_id := ($1->>'test_table_id')::INTEGER;
		SELECT table_name INTO _test_table_name FROM grape.test_table WHERE test_table_id=_test_table_id::INTEGER;
	END IF;

	EXECUTE FORMAT('SELECT json_agg(keys)
		FROM (SELECT json_object_keys(a.data) AS keys 
			FROM (SELECT data 
				FROM "%s"."%s" LIMIT 1) AS a) AS b', _result_schema, _result_table) INTO _columns;
	
	_rows := '[]'::JSONB;
	FOR _data IN EXECUTE FORMAT('SELECT data FROM "%s"."%s"', _result_schema, _result_table) LOOP
		_row := '[]'::JSONB;
		FOR _key IN SELECT value FROM json_array_elements_text(_columns) LOOP
			_row := _row || (_data->_key)::JSONB;
		END LOOP;
		_rows := _rows || jsonb_build_array(_row);
	END LOOP;

	_values := _rows::JSON;

	_test_table_spec := json_build_object('test_table_name', _test_table_name,
		'columns', _columns,
		'values', _values,
		'description', _description,
		'append', _append);

	_result := grape.test_table_insert(_test_table_spec);
	_test_table_id := (_result->>'test_table_id')::INTEGER;

	IF _test_table_id IS NOT NULL THEN
		UPDATE grape.data_import 
		SET test_table_id=_test_table_id
		WHERE data_import_id=_data_import_id::INTEGER;
	END IF;

	RETURN _result;
END; $$ LANGUAGE plpgsql;

/**
 * Api function to drop a test table from a data imports data
 */
CREATE OR REPLACE FUNCTION grape.data_import_test_table_drop(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_test_table_name TEXT;
	_test_table_schema TEXT;
	_result JSON;
	_test_table_id INTEGER;
BEGIN
	--TODO make sure data import id exists
	_test_table_id := ($1->>'test_table_id')::INTEGER;

	SELECT table_name, table_schema
	INTO _test_table_name, _test_table_schema
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;

	UPDATE grape.data_import 
	SET test_table_id=NULL
	WHERE test_table_id=_test_table_id;

	_result := grape.test_table_drop(json_build_object('test_table_schema', _test_table_schema, 
		'test_table_name', _test_table_name,
		'test_table_id', _test_table_id));
	
	RETURN _result;
END; $$ LANGUAGE plpgsql;

/**
 * Api function
 */
CREATE OR REPLACE FUNCTION grape.data_import_test_table_alter(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

/**
 *Example dimport function that does not process the data in any way and allows for a way to create a
 *test table with data that does not need to be processed.
 **/
CREATE OR REPLACE FUNCTION grape.dimport_generic (_data_import grape.data_import, _args JSONB) RETURNS JSON AS $$
DECLARE
	_ret JSON;
BEGIN
	--_data_import is a data_import record for the data_import_id that relates to this process, processing_param can be got from this
	--_args contains the following: 
	--	index: the index position of this process
	--	data_import_row_id: the data_import_row_id for this process
	--	data: the data to be processed
	--	shared_data: data accessable to all proccesses in their respective sequence

	--the return data should be in the folling format {"result":{"status":"OK"}}
	--the result object is what will be stored as the result for processed row
	--you can include shared_data if there is data you want to pass on to 
	--proceeding processes {"result":{"status":"OK"}, "shared_data":{}}
	_ret := '{"result": {"status":"OK"}}'::JSON;
	RETURN _ret;
END; $$ LANGUAGE plpgsql;

--upsert the generic processing_function type
SELECT grape.upsert_data_import_type('dimport_generic', 
	'Generic', 
	'This function does not actually process the data in any way, but is a way to allow you to import data, with which you may create test tables.', 
	'grape');

-- test_table functions
/**
 * api function to create a test table 
 * {"schema_name":"tmp", "table_name":"test", "columns":["colA", "colB"], "rows":[["row1colA", "row1colB"], ["row2colA", "row2colB"]]}
 */
CREATE OR REPLACE FUNCTION grape.test_table_insert(JSON) RETURNS JSON AS $$
DECLARE
	_schema_name TEXT;
	_table_name TEXT;
	_description TEXT;
	_columns TEXT := '';
	_row JSON;
	_field TEXT;
	_rows_inserted INTEGER := 0;
	_test_table_id INTEGER;
	_values TEXT := '';
	_append BOOLEAN;
	_new BOOLEAN;
	_user_id INTEGER;
	_current_user_id INTEGER;
BEGIN
	_current_user_id := current_user_id();
	_schema_name := grape.setting('test_table_schema', 'tmp');
	_table_name := $1->>'test_table_name';
	_description := $1->>'description';
	_append := ($1->>'append')::BOOLEAN;

	INSERT INTO grape.test_table (table_schema, table_name, description, date_created, user_id) 
		VALUES (_schema_name, _table_name, _description, current_timestamp, _current_user_id)
		ON CONFLICT(table_schema, table_name) DO UPDATE SET table_schema=EXCLUDED.table_schema 
		RETURNING test_table_id, user_id INTO _test_table_id, _user_id; 

	IF NOT EXISTS (SELECT 1
		FROM information_schema.tables 
		WHERE table_schema = _schema_name
		AND table_name = _table_name) THEN
		
		SELECT string_agg(CONCAT('"',regexp_replace(LOWER(item), '\s', '_', 'g'), '" TEXT'), ', ')
		INTO _columns
		FROM (SELECT json_array_elements_text($1->'columns') AS item) as a;

		EXECUTE FORMAT('CREATE TABLE IF NOT EXISTS "%s"."%s" (test_table_row_id SERIAL NOT NULL,
			%s, 
			CONSTRAINT %s_row_id_pk PRIMARY KEY (test_table_row_id))', _schema_name, _table_name, _columns, regexp_replace(_table_name, '\s', '_', 'g'));
		_new := TRUE;

	ELSIF _append IS NULL THEN
		RETURN grape.api_error('table already exists and append not specified', -2);
	END IF;

	--TODO check that columns of new data match that of table specified
	IF _append OR _new THEN
		--only allow user who created a test table to append to it.
		IF _append AND _current_user_id!=_user_id AND _current_user_id IS NOT NULL THEN
			return grape.api_error('Cannot append to this table as you are not the owner', -2);
		END IF;
		UPDATE grape.test_table SET date_updated = current_timestamp WHERE test_table_id=_test_table_id::INTEGER;

		SELECT string_agg(CONCAT('"',regexp_replace(LOWER(item), '\s', '_', 'g'),'"'), ', ')
		INTO _columns
		FROM (SELECT json_array_elements_text($1->'columns') AS item) as a;

		SELECT string_agg(format('(%s)', vals), ', ')
		INTO _values
		FROM (SELECT string_agg(quote_literal(txt), ', ') AS vals
			FROM (SELECT rown, json_array_elements_text(value) as txt
				FROM (SELECT row_number() over () AS rown, value
					FROM json_array_elements($1->'values')) AS a) AS b GROUP BY rown) AS c;
		
		EXECUTE FORMAT('INSERT INTO "%s"."%s" (%s) VALUES %s', _schema_name, _table_name, _columns, _values);
	END IF;

	RETURN grape.api_success('test_table_id', _test_table_id);
END; $$ LANGUAGE plpgsql;

/**
 * api function drop a specified test table 
 * 
 */
CREATE OR REPLACE FUNCTION grape.test_table_drop(JSON) RETURNS JSON AS $$
DECLARE
	_test_table_id TEXT;
	_schema_name TEXT;
	_table_name TEXT;
	_user_id INTEGER;
BEGIN
	--TODO make checks to be sure that this is a test table maybe check for col test_table_row_id?
	_test_table_id = ($1->>'test_table_id')::INTEGER;

	SELECT table_schema, table_name, user_id
	INTO _schema_name, _table_name, _user_id 
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;

	IF current_user_id() != _user_id THEN
		RETURN grape.api_error('Only the owner can delete this test table', -2);
	END IF;

	EXECUTE FORMAT('DROP TABLE "%s"."%s"', _schema_name, _table_name);

	DELETE FROM grape.test_table WHERE test_table_id = _test_table_id::INTEGER;
	
	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

/**
 * api function alter the datatypes for specified test table 
 * 
 */
CREATE OR REPLACE FUNCTION grape.test_table_alter(JSON) RETURNS JSON AS $$
DECLARE
	_test_table_id TEXT;
	_schema_name TEXT;
	_table_name TEXT;
BEGIN
	_test_table_id = $1->>'test_table_id'::INTEGER;

	SELECT table_schema, table_name
	INTO _schema_name, _table_name 
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;

	RETURN grape.api_success;
END; $$ LANGUAGE plpgsql;


-- list_query function
CREATE OR REPLACE FUNCTION grape.list_query(JSON) RETURNS JSON AS $$
DECLARE
	_offset INTEGER;
	_limit INTEGER;
        _sortfield TEXT;
        _sortsql TEXT;
        _ret JSON;
        _total INTEGER;
        _total_results INTEGER;
        _rec RECORD;
	_tablename TEXT;
	_schema TEXT;
	_page_number INTEGER;
	_total_pages INTEGER;

	_filters TEXT[];
	_filter_sql TEXT;
	_filter_json JSON;

	_oper TEXT;
	_filter_array TEXT[];
	_filters_join TEXT;

	_roles TEXT[];
	_user_roles TEXT[];

	_extra_data JSON := ($1->'extra_data');
BEGIN
	_offset := 0;
	_page_number := 0;
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN grape.api_error('Table requested is null', -5);
	END IF;

	_tablename := $1->>'tablename';

	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
	END IF;

	IF json_extract_path($1, 'filters_join') IS NOT NULL THEN
		_filters_join := UPPER($1->>'filters_join');
	END IF;

	IF _filters_join IS NULL OR _filters_join != 'OR' THEN
		_filters_join := 'AND';
	END IF;

	SELECT roles INTO _roles FROM grape.list_query_whitelist WHERE schema = _schema::TEXT AND _tablename::TEXT ~ tablename;
	IF NOT FOUND THEN
		RETURN grape.api_error('Table requested is not in whitelist', -2);
	END IF;

	IF NOT _roles @> '{all}' AND grape.current_user_in_role(_roles) = FALSE THEN
		SELECT array_agg(c) INTO _user_roles FROM grape.current_user_roles() c;
		RETURN grape.api_error('Permission denied to table ' || _schema::TEXT || '.' || _tablename::TEXT, 
			-2, 
			json_build_object('allowed_roles', _roles, 'user_roles', _user_roles)
		);
	END IF;

        IF json_extract_path($1, 'sortfield') IS NOT NULL THEN
                _sortfield := $1->>'sortfield';
		_sortsql := ' ORDER BY ' || quote_ident(_sortfield);

		IF json_extract_path_text($1, 'sortorder') = 'DESC' THEN
			_sortsql := _sortsql || ' DESC';
		END IF;

        ELSE
		_sortfield := '';
		_sortsql := '';
        END IF;

        IF json_extract_path($1, 'limit') IS NOT NULL THEN
		_limit := ($1->>'limit')::INTEGER;
        ELSE
                _limit := 50;
        END IF;

	IF json_extract_path($1, 'offset') IS NOT NULL THEN
		_offset := ($1->>'offset')::INTEGER;
	ELSIF json_extract_path($1, 'page_number') IS NOT NULL THEN
		_page_number := ($1->>'page_number')::INTEGER;
		_offset := (_page_number - 1) * _limit;
	END IF;

	IF _offset < 0 THEN
		_offset := 0;
	END IF;

	_page_number := _offset / _limit;

	_filters := '{}'::TEXT[];
	IF json_extract_path($1, 'filter') IS NOT NULL THEN
		FOR _filter_json IN SELECT json_array_elements(json_extract_path($1, 'filter')) LOOP

			_oper := '=';
			IF json_extract_path(_filter_json, 'operand') IS NOT NULL THEN
				_oper := _filter_json->>'operand';
			ELSIF json_extract_path(_filter_json, 'oper') IS NOT NULL THEN
				_oper := _filter_json->>'oper';
			ELSIF json_extract_path(_filter_json, 'op') IS NOT NULL THEN
				_oper := _filter_json->>'op';
			END IF;

			_oper := UPPER(_oper);
			IF _oper IN ('=', '>=', '>', '<', '<=', '!=', 'LIKE', 'ILIKE') THEN
				_filter_sql := CONCAT_WS(' ', quote_ident(_filter_json->>'field'), _oper, quote_literal(_filter_json->>'value'));
			ELSIF _oper = 'IS_NULL' THEN
				_filter_sql := CONCAT_WS(' ', quote_ident(_filter_json->>'field'), 'IS NULL');
			ELSIF _oper = 'IS_NOT_NULL' THEN
				_filter_sql := CONCAT_WS(' ', quote_ident(_filter_json->>'field'), 'IS NOT NULL');
			ELSIF _oper = 'IN' THEN
				SELECT array_agg(val.quoted) INTO _filter_array FROM
				(
					SELECT quote_literal(json_array_elements_text(_filter_json->'value')) quoted
				) val;

				_filter_sql := CONCAT(quote_ident(_filter_json->>'field'), '::TEXT = ANY (ARRAY[',  array_to_string(_filter_array, ','), ']::TEXT[])');
			ELSE
				CONTINUE;
			END IF;

			_filters := array_append(_filters, _filter_sql);
		END LOOP;
		IF array_length(_filters, 1) > 0 THEN
			_filter_sql := ' WHERE ' || array_to_string(_filters, ' ' || _filters_join || ' ');
		ELSE
			_filter_sql := '';
		END IF;
	ELSE
		_filter_sql := '';
	END IF;

	EXECUTE 'SELECT COUNT(*) FROM '  || quote_ident(_schema) || '.'  || quote_ident(_tablename) || ' ' || _filter_sql INTO _total;

	_total_pages := (_total / _limit)::INTEGER;
	IF MOD(_total, _limit) > 0 THEN
		_total_pages := _total_pages + 1;
	END IF;

	RAISE NOTICE 'Query: %', '(SELECT * FROM '  || quote_ident(_schema) || '.' || quote_ident(_tablename) || ' ' || _filter_sql || ' ' || _sortsql || ' OFFSET $1 LIMIT $2)';

	EXECUTE 'SELECT to_json(b) FROM '
		'(SELECT COUNT(*) AS "result_count", '
			'$1 AS "offset", '
			'$2 AS "limit", '
			'$3 AS "page_number", '
			'array_agg(a) AS records, '
			'$4 AS "total", '
			'$5 AS "total_pages", '
			'$6 AS "extra_data"'
		' FROM '
			'(SELECT * FROM '  || quote_ident(_schema) || '.' || quote_ident(_tablename) || ' ' || _filter_sql || ' ' || _sortsql || ' OFFSET $1 LIMIT $2) a'
		') b'
		USING _offset, _limit, _page_number, _total, _total_pages, _extra_data INTO _ret;

        RETURN _ret;
END; $$ LANGUAGE plpgsql;


-- session functions
CREATE OR REPLACE FUNCTION grape.session_insert (JSON) RETURNS JSON AS $$
DECLARE
	_user TEXT;
	_password TEXT;
	_email TEXT;
	_ip_address TEXT;

	rec RECORD;

	_session_id TEXT;
	_found BOOLEAN;

	_user_roles TEXT[];

	_ret JSON;

	_check_password TEXT;
BEGIN

	IF json_extract_path($1, 'username') IS NOT NULL THEN
		_user := $1->>'username';
		SELECT * INTO rec FROM grape."user" WHERE username=_user::TEXT;
	ELSIF json_extract_path($1, 'email') IS NOT NULL THEN
		_email := $1->>'email';
		SELECT * INTO rec FROM grape."user" WHERE email=_email::TEXT;
	ELSE
		RETURN grape.api_error_invalid_input('{"message":"Missing email or username"}');
	END IF;

	IF rec IS NULL THEN
		RAISE DEBUG 'User % % login failed. No such user', _user, _email;
		RETURN grape.api_result_error('No such user', 1);
	END IF;

	IF _user IS NULL THEN
		_user := rec.username;
	END IF;
	
	_password := $1->>'password';
	_ip_address := $1->>'ip_address';

	IF grape.get_value('disable_passwords', 'false') = 'false' THEN

		IF grape.get_value('passwords_hashed', 'false') = 'true' THEN
			_password := crypt(_password, rec.password);
			_check_password := rec.password;
		ELSE
			_check_password := rec.password;
		END IF;

		IF _check_password != _password THEN
			RAISE DEBUG 'User % login failed. Password does not match', _user;
			RETURN grape.api_result_error('Invalid password', 2);
		END IF;
	END IF;

	IF rec.active = false THEN
		RAISE DEBUG 'User % login failed. User is inactive', _user;
		RETURN grape.api_result_error('User not active', 3);
	END IF;

	-- generate unique session id
	_found = TRUE;
	WHILE _found = TRUE LOOP
		_session_id := grape.random_string(15);
		IF
			EXISTS (SELECT session_id FROM grape."session" WHERE session_id=_session_id::TEXT)
			OR EXISTS (SELECT session_id FROM grape."session_history" WHERE session_id=_session_id::TEXT)
		THEN
			_found := TRUE;
		ELSE
			_found := FALSE;
		END IF;
	END LOOP;

	RAISE DEBUG 'User % logged in successfuly from %. Session ID is now %', _user, _ip_address, _session_id;

	SELECT array_agg(role_name) INTO _user_roles FROM grape."user_role" WHERE user_id=rec.user_id::INTEGER;

	INSERT INTO grape."session" (session_id, ip_address, user_id, date_inserted, last_activity)
		VALUES (_session_id, _ip_address, rec.user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

	SELECT to_json(a) INTO _ret FROM (
		SELECT 'true' AS "success",
			'OK' AS "status",
			0 AS "code",
			_session_id AS "session_id",
			rec.user_id AS "user_id",
			_user AS "username",
			_user_roles AS "user_roles",
			rec.fullnames AS "fullnames",
			rec.email AS "email",
			rec.employee_guid AS "employee_guid"
		) a;

	PERFORM pg_notify('new_session', _ret::TEXT);

	RETURN _ret;
END; $$ LANGUAGE plpgsql;

-- is_weekdend_day function
CREATE OR REPLACE FUNCTION grape.is_weekend_day(DATE) RETURNS BOOLEAN AS $$
	SELECT CASE EXTRACT(dow FROM $1) 
		WHEN 0 THEN TRUE 
		WHEN 6 THEN TRUE 
		ELSE FALSE 
	END;
$$ LANGUAGE 'sql' STRICT IMMUTABLE;

COMMIT;