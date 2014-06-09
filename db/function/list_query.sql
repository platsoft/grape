

/**
 * Input fields:
 * 	tablename
 *   	sortfield (optional) text
 *	limit (optional) integer default 50
 * 	offset (optional) integer default 0
 * 	filter (optional) array of fields:
 *		field text
 *		operand text of '=', '>', '<', '>=', '<='
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
	_page_number INTEGER;

	_filters TEXT[];
	_filter_sql TEXT;
	_filter_json JSON;
BEGIN
	_offset := 0;
	_page_number := 0;

	IF json_extract_path($1, 'tablename') IS NULL THEN
		RETURN NULL;
	END IF;

	_tablename := $1->>'tablename';

        IF json_extract_path($1, 'sortfield') IS NOT NULL THEN
                _sortfield := $1->>'sortfield';
		_sortsql := ' ORDER BY ' || quote_ident(_sortfield);
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
			IF NOT _filter_json->>'operand' IN ('=', '>=', '>', '<', '<=', '!=') THEN
				continue;
			END IF;
			_filter_sql := quote_ident(_filter_json->>'field') || ' ' || (_filter_json->>'operand') || ' ' || quote_literal(_filter_json->>'value') || '';
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

	EXECUTE 'SELECT COUNT(*) FROM '  || quote_ident(_tablename) || ' ' || _filter_sql INTO _total;

	EXECUTE 'SELECT to_json(b) FROM '
		'(SELECT COUNT(a) AS "result_count", '
			'$1 AS "offset", '
			'$2 AS "limit", '
			'$3 AS "page_number", '
			'array_agg(a) AS records, '
			'$4 AS "total", '
			'($4/$2)+1 AS "total_pages" '
		' FROM '
			'(SELECT * FROM ' || quote_ident(_tablename) || ' ' || _filter_sql || ' ' || _sortsql || ' OFFSET $1 LIMIT $2) a'
		') b' 
		USING _offset, _limit, _page_number, _total INTO _ret;

        RETURN _ret;
END; $$ LANGUAGE plpgsql;



