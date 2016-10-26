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
		RETURN grape.api_error('table already exists and append not specified', -1);
	END IF;

	--TODO check that columns of new data match that of table specified
	IF _append OR _new THEN
		--only allow user who created a test table to append to it.
		IF _append AND _current_user_id!=_user_id AND _current_user_id IS NOT NULL THEN
			return grape.api_error('Cannot append to this table as you are not the owner', -1);
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
BEGIN
	--TODO make checks to be sure that this is a test table maybe check for col test_table_row_id?
	_test_table_id = ($1->>'test_table_id')::INTEGER;

	SELECT table_schema, table_name
	INTO _schema_name, _table_name 
	FROM grape.test_table 
	WHERE test_table_id = _test_table_id::INTEGER;

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
