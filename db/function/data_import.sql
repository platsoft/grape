
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
BEGIN
	_data_import_id := $1->>'data_import_id';

	IF _data_import_id IS NULL THEN
		RETURN grape.api_error('data_import_id was not provided', -1);
	END IF;

	SELECT result_schema, result_table, data_import_status  
	INTO _schema, _tablename, _data_import_status 
	FROM grape.data_import
	WHERE data_import_id=_data_import_id::INTEGER ;

	--delete only if table can be found and non of the rows for the data_import has been proccessed
	IF _tablename IS NULL THEN
		RETURN grape.api_error(FORMAT('Could not find data_import_id: %s', _data_import_id), -1);
	ELSIF _data_import_status > 1 THEN
		RETURN grape.api_error('Cannot delete this as some or all of its data has been processed', -1);
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
 * Api function to return json with all the data rows
 * Required field data_import_id must be in the JSON data
 * normally grape list would be used for this sort of thing but grape list does not work with dynamic table and schema names
 */
CREATE OR REPLACE FUNCTION grape.data_import_detail(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_schema TEXT;
	_tablename TEXT;
	_data_import_detail JSON;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	SELECT result_table, result_schema INTO _tablename, _schema FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;

	EXECUTE FORMAT ('SELECT to_json(b)
					FROM
						(SELECT count(*) AS result_count,
							array_agg(a) AS records
							FROM
						(SELECT * FROM "%s"."%s") AS a) AS b', _schema, _tablename) INTO _data_import_detail;

	RETURN grape.api_success(_data_import_detail);
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
		RETURN grape.api_error('data_import_id not provided', -1);
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
BEGIN
	--TODO make sure data import id exists
	_data_import_id := ($1->>'data_import_id')::INTEGER;
	_test_table_name := $1->>'test_table_name';
	_description := $1->>'description';

	SELECT result_table, result_schema
	INTO _result_table, _result_schema
	FROM grape.data_import 
	WHERE data_import_id = _data_import_id::INTEGER;

	EXECUTE FORMAT('SELECT json_agg(keys)
		FROM (SELECT json_object_keys(a.data) AS keys 
			FROM (SELECT data 
				FROM "%s"."%s" LIMIT 1) AS a) AS b', _result_schema, _result_table) INTO _columns;

	EXECUTE FORMAT('SELECT json_agg(vals) 
		FROM (SELECT json_agg((pair).value) AS vals
				FROM (SELECT data_import_row_id, json_each_text(a.data) as pair
					FROM (SELECT data_import_row_id, data
						FROM "%s"."%s") AS a) as b
						GROUP BY data_import_row_id) as c', _result_schema, _result_table) INTO _values;

	_test_table_spec := json_build_object('test_table_name', _test_table_name,
		'columns', _columns,
		'values', _values,
		'description', _description);

	_test_table_id := grape.test_table_insert(_test_table_spec);

	IF _test_table_id IS NOT NULL THEN
		UPDATE grape.data_import 
		SET test_table_id=_test_table_id
		WHERE data_import_id=_data_import_id::INTEGER;
	ELSE
		RETURN grape.api_error('Can not create Table as it already exists, maybe you meant to append to the table instead?', -1);
	END IF;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql;

/**
 * Api function to drop a test table from a data imports data
 */
CREATE OR REPLACE FUNCTION grape.data_import_test_table_drop(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_test_table_name TEXT;
	_test_table_schema TEXT;
	_result INTEGER;
	_test_table_id INTEGER;
BEGIN
	--TODO make sure data import id exists
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	SELECT test_table_name, test_table_schema
	INTO _test_table_name, _test_table_schema
	FROM grape.data_import AS di
	JOIN grape.test_table AS tt USING(test_table_id) 
	WHERE data_import_id = _data_import_id::INTEGER;

	_result := grape.test_table_drop(json_build_object('test_table_schema', _test_table_schema, 
		'test_table_name', _test_table_name));

	IF _result = 1 THEN
		UPDATE grape.data_import 
		SET test_table_schema=NULL, test_table_name=NULL
		WHERE data_import_id=_data_import_id;
	END IF;
	
	RETURN grape.api_success('code', _result);
END; $$ LANGUAGE plpgsql;

/**
 * Api function 
 */
CREATE OR REPLACE FUNCTION grape.data_import_test_table_select(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_options JSON;
	_test_table_id TEXT;
	_result JSON;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;
	_options := $1->'options';

	SELECT test_table_id
	INTO _test_table_id
	FROM grape.data_import 
	WHERE data_import_id = _data_import_id::INTEGER;

	_result := grape.test_table_select(json_build_object('test_table_id', _test_table_id, 'options', _options));

	RETURN grape.api_success(_result);
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
	'', 
	'grape');
