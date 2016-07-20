
\echo 'Test 1'
-- {"status":"OK"}
SELECT grape.api_success();

\echo 'Test 2'
-- {"status":"ERROR","message":"An error","code":-10}
SELECT grape.api_result_error('An error', -10);

\echo 'Test 3'
-- {"status":"OK","data":{"something":{"aaa":10}}}
SELECT grape.api_success('data', '{"something":{"aaa":10}}'::JSON);

\echo 'Test 4'
SELECT grape.api_result((true, 'Meh', '{"something":{"aaa":10}}'::JSON)::grape.grape_result_type);

\echo 'Test 5'
SELECT grape.api_result((false, 'Meh', '{"code":-10}'::JSON)::grape.grape_result_type);

\echo 'Test 6'
SELECT grape.api_result((false, 'Meh', NULL::JSON)::grape.grape_result_type);

\echo 'Test 7'
SELECT grape.api_success('{"something_numeric":30,"something_text":"bah"}'::JSON);

\echo 'Test 8'
SELECT grape.api_result_error('An error', -20);

