

/**
 * Input fields:
 * 	tablename
 * 	schema (optional) text
 *   	sortfield (optional) text
 * 	sortorder (optional) text DESC
 *	limit (optional) integer default 50
 * 	offset (optional) integer default 0
 * 	filter (optional) array of fields:
 *		field text
 *		operand text of '=', '>', '<', '>=', '<=', 'LIKE', 'ILIKE'
 *		value text
 * Returns a list object:  { total: INT, offset: INT, limit: INT, result_count: INT, records: [ {} ] }
 */
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
BEGIN
	_offset := 0;
	_page_number := 0;
	_schema := 'public';

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN NULL;
	END IF;

	_tablename := $1->>'tablename';

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
        
	IF json_extract_path($1, 'schema') IS NOT NULL THEN
		_schema := $1->>'schema';
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

			IF NOT _oper IN ('=', '>=', '>', '<', '<=', '!=', 'LIKE', 'ILIKE') THEN
				CONTINUE;
			END IF;

			_filter_sql := quote_ident(_filter_json->>'field') || ' ' || _oper || ' ' || quote_literal(_filter_json->>'value') || '';
			_filters := array_append(_filters, _filter_sql);
		END LOOP;
		IF array_length(_filters, 1) > 0 THEN
			_filter_sql := ' WHERE ' || array_to_string(_filters, ' AND ');
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
			'$5 AS "total_pages" '
		' FROM '
			'(SELECT * FROM '  || quote_ident(_schema) || '.' || quote_ident(_tablename) || ' ' || _filter_sql || ' ' || _sortsql || ' OFFSET $1 LIMIT $2) a'
		') b' 
		USING _offset, _limit, _page_number, _total, _total_pages INTO _ret;

        RETURN _ret;
END; $$ LANGUAGE plpgsql;



