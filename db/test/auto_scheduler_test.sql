BEGIN;

SET client_min_messages TO ERROR;

CREATE OR REPLACE FUNCTION run_auto_scheduler_test (JSON) RETURNS VOID AS $$
DECLARE
	_auto_schedule_id INTEGER;
	_ret JSON;
	_rec RECORD;
	_now TIMESTAMP;
BEGIN

	_now := ('2016/01/01 13:00')::TIMESTAMP; -- 1 jan 2016 friday

	_ret := grape.save_process_auto_scheduler($1); 
	_auto_schedule_id := (_ret->>'auto_scheduler_id')::INTEGER;
	DELETE FROM grape.schedule WHERE auto_scheduler_id=_auto_schedule_id::INTEGER;
	PERFORM grape.autoschedule_next(_auto_schedule_id, _now);
	PERFORM grape.autoschedule_next(_auto_schedule_id, _now);
	PERFORM grape.autoschedule_next(_auto_schedule_id, _now);
	PERFORM grape.autoschedule_next(_auto_schedule_id, _now);
	PERFORM grape.autoschedule_next(_auto_schedule_id, _now);

	RAISE NOTICE 'Results for Auto Schedule: %', $1;
	FOR _rec IN SELECT * FROM grape.schedule WHERE auto_scheduler_id=_auto_schedule_id::INTEGER ORDER BY time_sched ASC LOOP
		RAISE NOTICE '%, %, %', _rec.time_sched, _rec.param, COALESCE(_rec.user_id, 0);
	END LOOP;

	RETURN;
END; $$ LANGUAGE plpgsql;

-- Specifiying times
\echo every 1st and 15th at 01:00
SELECT run_auto_scheduler_test('{"process_id":1,"days_of_month":"1,15","day_time":"01:00"}');
\echo every 1st and 15th at 23:00
SELECT run_auto_scheduler_test('{"process_id":1,"days_of_month":"1,15","day_time":"23:00"}');

\echo every TODAYs day of the month at 01:00
SELECT run_auto_scheduler_test(('{"process_id":1,"days_of_month":"' || EXTRACT('day' from current_date)::TEXT || '","day_time":"01:00"}')::JSON);
\echo every TODAYs day of the month at 23:00
SELECT run_auto_scheduler_test(('{"process_id":1,"days_of_month":"' || EXTRACT('day' from current_date)::TEXT || '","day_time":"23:00"}')::JSON);

\echo every day at 01:00 with user id and parameters
SELECT run_auto_scheduler_test('{"process_id":1,"day_time":"01:00","user_id":1,"params":{"a":20}}');
\echo every day at 23:00
SELECT run_auto_scheduler_test('{"process_id":1,"day_time":"23:00"}');

\echo every weekday at 15:00
SELECT run_auto_scheduler_test('{"process_id":1,"dow":"0111110","day_time":"15:00"}');

-- Specificyng intervals
\echo every 3 hours on every weekday 
SELECT run_auto_scheduler_test('{"process_id":1,"dow":"0111110","scheduled_interval":"3 hours"}');
\echo every 6 hours on every saturday
SELECT run_auto_scheduler_test('{"process_id":1,"dow":"0000001","scheduled_interval":"6 hours"}');
\echo every 8 hours every day
SELECT run_auto_scheduler_test('{"process_id":1,"scheduled_interval":"8 hours"}');
\echo every 8 hours every 1st of the month
SELECT run_auto_scheduler_test('{"process_id":1,"scheduled_interval":"8 hours","days_of_month":"1"}');


DROP FUNCTION run_auto_scheduler_test (JSON);

ROLLBACK;

