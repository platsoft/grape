/**
 * api function to create a test table 
 * {"schema_name":"tmp", "table_name":"test", "columns":["colA", "colB"], "rows":[["row1colA", "row1colB"], ["row2colA", "row2colB"]]}
 */
CREATE OR REPLACE FUNCTION grape.test_table_insert(JSON) RETURNS INTEGER AS $$
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
BEGIN
	_schema_name := grape.setting('test_table_schema', 'tmp');
	_table_name := $1->>'test_table_name';
	_description := $1->>'description';
	_append := ($1->>'append')::BOOLEAN;

	INSERT INTO grape.test_table (table_schema, table_name, description) VALUES (_schema_name, _table_name)
	ON CONFLICT(table_schema, table_name) DO NOTHING RETURNING test_table_id INTO _test_table_id; 

	IF NOT EXISTS (SELECT 1
		FROM information_schema.tables 
		WHERE table_schema = _schema_name
		AND table_name = _table_name) THEN
		
		SELECT string_agg(CONCAT('"',item, '" TEXT'), ', ')
		INTO _columns
		FROM (SELECT json_array_elements_text($1->'columns') AS item) as a;

		EXECUTE FORMAT('CREATE TABLE IF NOT EXISTS "%s"."%s" (test_table_row_id SERIAL NOT NULL,
			%s, 
			CONSTRAINT %s_row_id_pk PRIMARY KEY (test_table_row_id))', _schema_name, _table_name, _columns, regexp_replace(_table_name, '\s', '_', 'g'));
		_append := TRUE;

	ELSIF NOT _append THEN
		RETURN NULL;
	END IF;

	--TODO check that columns of new data match that of table specified
	IF _append THEN
		SELECT string_agg(CONCAT('"',item,'"'), ', ')
		INTO _columns
		FROM (SELECT json_array_elements_text($1->'columns') AS item) as a;

		SELECT string_agg(_vals, ', ')
		INTO _values 
		FROM (SELECT CONCAT('(','''',array_to_string(value::TEXT[], ''', '''),'''', ')') AS _vals
			FROM json_array_elements($1->'values')) AS a;

		EXECUTE FORMAT('INSERT INTO "%s"."%s" (%s) VALUES %s', _schema_name, _table_name, _columns, _values);
	END IF;

	RETURN _test_table_id;
END; $$ LANGUAGE plpgsql;

/**
 * api function drop a specified test table 
 * 
 */
CREATE OR REPLACE FUNCTION grape.test_table_drop(JSON) RETURNS INTEGER AS $$
DECLARE
	_test_table_id TEXT;
	_schema_name TEXT;
	_table_name TEXT;
BEGIN
	--TODO make checks to be sure that this is a test table maybe check for col test_table_row_id?
	_test_table_id = $1->>'test_table_id'::INTEGER;

	SELECT table_schema, table_name
	INTO _schema_name, _table_name 
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;

	EXECUTE FORMAT('DROP TABLE "%s"."%s"', _schema_name, _table_name);

	DELETE FROM grape.test_table WHERE test_table_id = _test_table_id::INTEGER;
	
	RETURN 1;
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

	RETURN 1;
END; $$ LANGUAGE plpgsql;

/**
 * api function to select and return the data and datatypes for a specified test table 
 * 
 */
CREATE OR REPLACE FUNCTION grape.test_table_select(JSON) RETURNS JSON AS $$
DECLARE
	_test_table_id TEXT;
	_schema_name TEXT;
	_table_name TEXT;
	_records JSON;
	_limit TEXT;
	_offset TEXT;
BEGIN
	--TODO use test_table_id
	_test_table_id = $1->>'test_table_id'::INTEGER;

	SELECT table_schema, table_name
	INTO _schema_name, _table_name 
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;
	
	_limit := $1->'options'->>'limit';
	_offset := $1->'options'->>'offset';

	EXECUTE FORMAT('SELECT json_agg(row_to_json("%s".*)) FROM "%s"."%1$s" OFFSET %s LIMIT %s', 
		_table_name, 
		_schema_name, 
		_offset,
		_limit) INTO _records;


	RETURN json_build_object('records', _records);
END; $$ LANGUAGE plpgsql;