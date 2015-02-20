
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
BEGIN
	_filename := $1->>'filename';
	_description := $1->>'description';

	INSERT INTO grape.data_import (filename, description, parameter, date_done) VALUES (_filename, _description, $1, NULL) 
		RETURNING data_import_id INTO _data_import_id;
	
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
BEGIN
	_data_import_id := ($1->>'data_import_id')::INTEGER;

	INSERT INTO grape.data_import_row(data_import_id, data) VALUES (_data_import_id, $1);
	
	RETURN '{}'::JSON;
END; $$ LANGUAGE plpgsql;


