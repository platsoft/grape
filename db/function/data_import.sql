
/**
 * Process uploaded file accepting JSON argument
 */
CREATE OR REPLACE FUNCTION grape.upsert_data_import_type(
	_processing_function TEXT, 
	_full_description TEXT, 
	_file_format_info TEXT, 
	_function_schema TEXT, 
	_param_definition JSON DEFAULT NULL) RETURNS VOID AS $$
	INSERT INTO grape.data_import_type (
		processing_function, 
		full_description, 
		file_format_info, 
		function_schema, 
		param_definition) 
	VALUES (
		_processing_function, 
		_full_description, 
		_file_format_info, 
		_function_schema, 
		_param_definition)
	ON CONFLICT (processing_function) 
	DO UPDATE SET full_description=EXCLUDED.full_description,
		file_format_info=EXCLUDED.file_format_info, 
		function_schema=EXCLUDED.function_schema;
$$ LANGUAGE sql;
/**
 * {
 *	filename TEXT
 *	description TEXT
 *	body JSON Any other data associated to this data import
 * }
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

	INSERT INTO grape.data_import (filename, description, parameter, date_done, record_count, valid_record_count, processing_function, processing_param, data_import_status) 
		VALUES (_filename, _description, $1, NULL, 0, 0, _processing_function, _processing_param, 0) 
		RETURNING data_import_id INTO _data_import_id;
	
	_schema := grape.setting('data_import_schema', 'grape');
	_tablename := FORMAT('data_import_%s', _data_import_id);
	_idxname := FORMAT('%s_data_import_row_idx', _tablename);

	EXECUTE FORMAT('CREATE TABLE "%s"."%s" () INHERITS (grape.data_import_row)', _schema, _tablename);
	EXECUTE FORMAT('CREATE INDEX "%s" ON "%s"."%s" (data_import_row_id)', _idxname, _schema, _tablename);

	UPDATE grape.data_import SET 
		result_table=_tablename, 
		result_schema=_schema 
	WHERE 
		data_import_id=_data_import_id::INTEGER;

	RETURN grape.api_success('data_import_id', _data_import_id);
END; $$ LANGUAGE plpgsql;

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

	IF _tablename IS NULL THEN
		RETURN grape.api_error(FORMAT('Could not find data_import_id: %s', _data_import_id), -1);
	ELSIF _data_import_status > 1 THEN
		RETURN grape.api_error('Cannot delete this as some or all of its data has been processed', -1);
	END IF;

	EXECUTE FORMAT('DROP TABLE "%s"."%s"', _schema, _tablename);

	DELETE FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER; 

	RETURN grape.api_success();

END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.data_import_done(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	UPDATE grape.data_import SET date_done=CURRENT_TIMESTAMP, data_import_status=1 WHERE data_import_id=_data_import_id::INTEGER;
	
	RETURN grape.api_success('data_import_id', _data_import_id);
END; $$ LANGUAGE plpgsql;


/**
 * Insert a row of JSON into data_import_row
 * Required field data_import_id must be in the JSON data
 */
CREATE OR REPLACE FUNCTION grape.data_import_row_insert(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
	_schema TEXT;
	_tablename TEXT;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	SELECT result_table, result_schema INTO _tablename, _schema FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;

	EXECUTE FORMAT ('INSERT INTO "%s"."%s" (data_import_id, data) VALUES ($1, $2)', _schema, _tablename) USING _data_import_id, $1;
	
	UPDATE grape.data_import SET record_count = record_count+1 WHERE data_import_id=_data_import_id::INTEGER;

	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;

/**
 * return json with all the data rows
 * Required field data_import_id must be in the JSON data
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
 * Process uploaded file
 */
CREATE OR REPLACE FUNCTION grape.data_import_process(_data_import_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_schema TEXT;
	_tablename TEXT;
	_processing_function TEXT;
	_processing_param JSON;

	_function_schema TEXT;
	_data_import_row_id INTEGER;

	_data JSON;
	_result JSON;
	_all_passed BOOLEAN := TRUE;
BEGIN
	SELECT result_table, result_schema, processing_function, processing_param 
	INTO _tablename, _schema, _processing_function, _processing_param
	FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;
	
	SELECT function_schema INTO _function_schema FROM grape.data_import_type WHERE processing_function=_processing_function::TEXT;

	FOR _data_import_row_id, _data IN EXECUTE FORMAT('SELECT data_import_row_id, data FROM "%s"."%s" WHERE processed=FALSE', _schema, _tablename) LOOP
		EXECUTE FORMAT ('SELECT "%s"."%s" ($1, $2)', _function_schema, _processing_function) USING _data, _processing_param INTO _result;
		EXECUTE FORMAT ('UPDATE "%s"."%s" SET processed=TRUE, result=$1 WHERE data_import_row_id=$2', _schema, _tablename) USING _result, _data_import_row_id;
		IF _result->>'status'='OK' THEN
			UPDATE grape.data_import SET valid_record_count=valid_record_count+1 WHERE data_import_id=_data_import_id::INTEGER;
		ELSE
			_all_passed := FALSE;
		END IF;
	END LOOP;
	
	IF _all_passed THEN
		UPDATE grape.data_import SET data_import_status=4 WHERE data_import_id=_data_import_id::INTEGER;
	ELSE
		UPDATE grape.data_import SET data_import_status=3 WHERE data_import_id=_data_import_id::INTEGER;
	END IF;

	RETURN 1;
END; $$ LANGUAGE plpgsql;

/**
 * Process uploaded file accepting JSON argument
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



