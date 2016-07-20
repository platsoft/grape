
/*

CREATE OR REPLACE FUNCTION json_diff_test (_old JSON, _new JSON, _expected JSONB) RETURNS INTEGER AS $$
DECLARE
	_ret JSONB;
BEGIN
	_ret := grape.json_diff(_old::JSONB, _new::JSONB);
	IF _ret = _expected OR (_ret IS NULL AND _expected IS NULL) THEN
		RAISE NOTICE 'PASSED (% MATCH %)', _ret::TEXT, _expected;
		RETURN 0;
	ELSE
		RAISE NOTICE 'FAILED: % DOES NOT MATCH %', _ret::TEXT, _expected;
		RETURN 1;
	END IF;
END; $$ LANGUAGE plpgsql;

\set VERBOSITY terse

-- different types
SELECT json_diff_test('["Hans"]', '{"name":"Hans"}', '{"name": "Hans"}');
-- same type and value
SELECT json_diff_test('"Hans"', '"Hans"', NULL);

-- object with one field added
SELECT json_diff_test('{"name":"Hans"}', '{"name":"Hans","surname":"Lombard"}', '{"surname": "Lombard"}');

-- object with one field removed
SELECT json_diff_test('{"name":"Hans","surname":"Lombard"}', '{"surname":"Lombard"}', '{}');

-- object with one field changed
SELECT json_diff_test('{"name":"Hans","surname":"Lombard"}', '{"name":"Piet","surname":"Lombard"}', '{"name": "Piet"}');

-- object with one field added and one field changed
SELECT json_diff_test('{"name":"Hans","mobile":"0821234567"}', '{"name":"Piet","surname":"Lombard","mobile":"0821234567"}', '{"name": "Piet", "surname": "Lombard"}');

-- object with one field removed, one field added, one field changed and one field the same
SELECT json_diff_test('{"name":"Hans","mobile":"0821234567","surname":"Lombard"}', '{"middlename":"Jurgens","surname":"Pompies","mobile":"0821234567"}', '{"middlename":"Jurgens", "surname":"Pompies"}');

-- array with one extra item
SELECT json_diff_test('[1,2]', '[1,2,3]', '[3]');
-- array with one overlapping and 2 extra items
SELECT json_diff_test('[1,2,3]', '[3,4,5]', '[4, 5]');

-- object with array field with an added value
SELECT json_diff_test('{"list": [1,2,3]}', '{"list": [1,2,3,4]}', '{"list":[4]}');

-- object with array field with an added value
SELECT json_diff_test('{"list": [1,2,3]}', '{"list": [1,2,3,4]}', '{"list":[4]}');


*/

