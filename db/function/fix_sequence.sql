
CREATE OR REPLACE FUNCTION grape.check_sequence(_schema TEXT, _name TEXT, OUT sequence regclass, OUT current_value INTEGER, OUT actual_value INTEGER)
AS $$
DECLARE
	_max_value INTEGER := 0;
	_column RECORD;
BEGIN
	sequence = CONCAT_WS('.', quote_ident(_schema), quote_ident(_name))::regclass;

	EXECUTE 'SELECT last_value FROM ' || sequence::text
		INTO current_value;

	actual_value := 1;

	FOR _column IN
		SELECT * FROM information_schema.columns
			WHERE column_default = CONCAT('nextval(''', sequence::text, '''::regclass)')
			OR column_default = CONCAT('nextval(''', _schema, '.', _name, '''::regclass)')
			OR column_default = CONCAT('nextval(''', _name, '''::regclass)')
	LOOP
		EXECUTE 'SELECT MAX(' || quote_ident(_column.column_name) || ') FROM ' || quote_ident(_column.table_schema) || '.' || quote_ident(_column.table_name)
			INTO _max_value;

		actual_value := GREATEST(actual_value, _max_value);
	END LOOP;

	RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.fix_sequence(_schema TEXT, _name TEXT) RETURNS INTEGER AS $$
DECLARE
	_data RECORD;
BEGIN
	_data := grape.check_sequence(_schema, _name);

	IF _data.actual_value IS NOT NULL AND _data.actual_value <> _data.current_value THEN
		RAISE NOTICE 'Fixing value for % from % to %', _data.sequence, _data.current_value, _data.actual_value;
		RETURN setval(_data.sequence, _data.actual_value);
	END IF;

	RETURN _data.actual_value;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.fix_all_sequences() RETURNS INTEGER AS $$
	SELECT COUNT(*)::INTEGER FROM (
		WITH a AS (SELECT * FROM information_schema.sequences JOIN LATERAL grape.check_sequence(sequence_schema, sequence_name) cs ON TRUE)
		SELECT grape.fix_sequence(sequence_schema, sequence_name) FROM a WHERE current_value <> actual_value
	) a;
$$ LANGUAGE sql;
