
CREATE OR REPLACE VIEW grape.type_summary AS
	SELECT
		ns.nspname AS schema,
		ty.typname AS type_name,
		attr.attname AS attribute_name,
		FORMAT_TYPE(attr.atttypid, NULL) AS attribute_type,
		(ty_target.typtype = 'c' OR COALESCE(ty_target_array.typtype, '') = 'c') AS is_composite,
		ty_target.typelem <> 0 AND ty_target.typlen < 0 AS is_array
	FROM pg_type ty
		JOIN pg_namespace ns ON ty.typnamespace = ns.oid -- To allow filtering by namespace name instead of namespace oid
		JOIN pg_attribute attr ON attr.attrelid = ty.typrelid AND attr.attnum >= 0 -- To get only attributes that represent composite types
		JOIN pg_type ty_target ON ty_target.oid = attr.atttypid
		LEFT OUTER JOIN pg_type ty_target_array ON ty_target_array.oid = ty_target.typelem
	WHERE
		ty.typtype= 'c' -- We are only interested in composite types
		AND ns.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') -- Exclude built-in schema tables
	ORDER BY
		attr.attnum
	;


CREATE OR REPLACE FUNCTION grape.json_to_composite_type_text(target_schema TEXT, target_type TEXT, data JSON) RETURNS TEXT
AS $$
DECLARE
	_is_array BOOLEAN;
	_param_value TEXT;

	_is_param_array BOOLEAN;
	_result TEXT;

	_type_data RECORD;
	_temp_value TEXT;
	_temp_array_value TEXT;
	_temp_json JSON;
BEGIN
	_result := '';
	_temp_array_value := '';

	-- Determine if the top-level type is an array
	_is_array := target_type LIKE '%[]';
	IF _is_array THEN
		target_type := SUBSTRING(target_type FROM 1 FOR LENGTH(target_type) - 2);
	END IF;

	-- Loop through all parameters
	FOR _type_data IN SELECT * FROM grape.type_summary WHERE schema = target_schema AND type_name = target_type LOOP
		-- Cache the parameter value for use throughout the rest of the function
		_param_value := (data ->> _type_data.attribute_name)::TEXT;
		_result := _result || ',';

		-- Add empty entries
		IF _param_value IS NULL THEN
			_result := _result || 'NULL';
			continue;
		END IF;

		IF _type_data.is_array THEN
			_result := _result || 'ARRAY[' ;
			-- Loop over the array
			FOR _param_value IN SELECT * FROM JSON_ARRAY_ELEMENTS_TEXT(_param_value::JSON) LOOP
				IF _type_data.is_composite THEN
					_temp_value := grape.json_to_composite_type_text( _type_data.schema, _type_data.attribute_type, _param_value::JSON );
					_result := _result ||  _temp_value || ',';
				ELSE
					_temp_value := _param_value;
					_result := _result || '''' || replace(_param_value, '''', '''''') || ''',';
				END IF;
			END LOOP;

			_result = RTRIM(_result, ',');
			_result := _result || ']::' || _type_data.attribute_type;
		ELSE
			IF _type_data.is_composite THEN
				_temp_value := grape.json_to_composite_type_text( _type_data.schema, _type_data.attribute_type, (data ->> _type_data.attribute_name)::json );
				_result := _result || _temp_value;
			ELSE
				_temp_value := _param_value;
				_result := _result || '''' || replace(_param_value, '''', '''''') || '''';
			END IF;
		END IF;
	END LOOP;

	-- Close the bracket loop and return
	RETURN 'ROW(' || SUBSTRING(_result FROM 2) || ')::' || target_schema || '.' || target_type;
END; $$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.json_to_composite_type(target_schema TEXT, target_type TEXT, data JSON) RETURNS RECORD AS $$
DECLARE
	txt TEXT;
	rec RECORD;
BEGIN

	SELECT grape.json_to_composite_type_text(target_schema, target_type, data) INTO txt;

	EXECUTE 'SELECT (a.ppp).* FROM (SELECT ' || txt || ' AS ppp) AS a' INTO rec;
	RETURN rec;
END; $$ LANGUAGE plpgsql;


