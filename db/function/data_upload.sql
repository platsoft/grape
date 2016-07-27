
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

	_processing_function TEXT;
BEGIN
	_filename := $1->>'filename';
	_description := $1->>'description';

	IF json_extract_path($1, 'processing_function') IS NOT NULL THEN
		_processing_function := $1->>'processing_function';
	END IF;

	INSERT INTO grape.data_import (filename, description, parameter, date_done, processing_function, data_import_status) 
		VALUES (_filename, _description, $1, NULL, _processing_function, 0) 
		RETURNING data_import_id INTO _data_import_id;
	
	_schema := grape.setting('data_upload_schema', 'grape');
	_tablename := FORMAT('data_import_%s', _data_import_id);

	EXECUTE FORMAT('CREATE UNLOGGED TABLE "%s"."%s" (data_import_row_id SERIAL, data JSON, processed BOOLEAN DEFAULT FALSE, result JSON)', _schema, _tablename);

	UPDATE grape.data_import SET result_table=_tablename, result_schema=_schema WHERE data_import_id=_data_import_id::INTEGER;

	RETURN grape.api_success('data_import_id', _data_import_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.data_upload_done(JSON) RETURNS JSON AS $$
DECLARE
	_data_import_id INTEGER;
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	UPDATE grape.data_import SET date_done=CURRENT_TIMESTAMP WHERE data_import_id=_data_import_id::INTEGER;
	
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

	EXECUTE FORMAT ('INSERT INTO "%s"."%s" (data) VALUES ($1)', _schema, _tablename) USING $1;
	
	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;

/**
 * Process uploaded file
 */
CREATE OR REPLACE FUNCTION grape.data_import_process(_data_import_id INTEGER) RETURNS INTEGER AS $$
DECLARE
	_schema TEXT;
	_tablename TEXT;
	_processing_function TEXT;

	_function_schema TEXT;

	_data JSON;
	_ret JSON;
BEGIN
	SELECT result_table, result_schema, processing_function INTO _tablename, _schema, _processing_function FROM grape.data_import WHERE data_import_id=_data_import_id::INTEGER;
	
	SELECT function_schema INTO _function_schema FROM grape.data_import_type WHERE processing_function=_processing_function::TEXT;

	FOR _data IN EXECUTE FORMAT('SELECT data FROM "%s"."%s" WHERE processed=FALSE', _schema, _tablename) LOOP
		
	END LOOP;
	
END; $$ LANGUAGE plpgsql;





