
/**
 *
 * days_of_month '*' or something like '1,15'
 * dow ('0111110')
 * process_id or process_name
 * scheduled_interval or day_time
 * auto_scheduler_id to update one of it
 * active BOOLEAN
 * params JSON
 */
CREATE OR REPLACE FUNCTION grape.save_process_auto_scheduler (JSON) RETURNS JSON AS $$
DECLARE
	_process_id INTEGER;
	_scheduled_interval INTERVAL;
	_dow TEXT;
	_dom TEXT;
	_time TIME;
	_run_as_user_id INTEGER;
	_auto_scheduler_id INTEGER;
	_run_with_params JSON;
	_active BOOLEAN;
BEGIN
	IF json_extract_path($1, 'auto_scheduler_id') IS NOT NULL THEN
		_auto_scheduler_id := ($1->>'auto_scheduler_id')::INTEGER;

		SELECT process_id, scheduled_interval, dow, days_of_month, day_time, run_with_params, run_as_user_id, active
		INTO _process_id, _scheduled_interval, _dow, _dom, _time, _run_with_params, _run_as_user_id, _active
			FROM grape.auto_scheduler
			WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	ELSE
		-- defaults
		_run_with_params := '{}';
		_run_as_user_id := current_user_id();
		_active := TRUE;
	END IF;


	IF json_extract_path($1, 'process_id') IS NOT NULL THEN
		_process_id := ($1->>'process_id')::INTEGER;
	ELSIF json_extract_path($1, 'process_name') IS NOT NULL THEN
		_process_id := grape.process_id_by_name($1->>'process_name');
	END IF;

	IF _process_id IS NULL THEN
		RETURN grape.api_error_invalid_input();
	END IF;

	IF json_extract_path($1, 'scheduled_interval') IS NOT NULL THEN
		_scheduled_interval := ($1->>'scheduled_interval')::INTERVAL;
	END IF;

	IF json_extract_path($1, 'dow') IS NOT NULL THEN
		_dow := $1->>'dow';
		IF _dow !~* '^([01]){7}$' THEN
			RETURN grape.api_result_error('Invalid input - dow should be a 7-character string containing ones and zeros', -2);
		END IF;
	END IF;

	IF json_extract_path($1, 'days_of_month') IS NOT NULL THEN
		_dom := $1->>'days_of_month';
	END IF;

	IF json_extract_path($1, 'day_time') IS NOT NULL THEN
		_time := ($1->>'day_time')::TIME;
	END IF;

	IF json_extract_path($1, 'params') IS NOT NULL THEN
		_run_with_params := $1->'params';
	END IF;

	IF json_extract_path($1, 'user_id') IS NOT NULL THEN
		_run_as_user_id := ($1->>'user_id')::INTEGER;
	END IF;

	IF json_extract_path($1, 'active') IS NOT NULL THEN
		_active := ($1->>'active')::BOOLEAN;
	END IF;


	IF _time IS NOT NULL AND _scheduled_interval IS NOT NULL THEN
		RETURN grape.api_result_error('Invalid input - cannot provide interval and time', -3);
	END IF;

	IF _scheduled_interval IS NOT NULL AND _scheduled_interval >= '1 day'::INTERVAL THEN
		RETURN grape.api_result_error('Invalid input - interval cannot be longer than a day', -3);
	END IF;

	IF _scheduled_interval IS NULL AND _time IS NULL THEN
		RETURN grape.api_result_error('Invalid input - need to provide either day_time or scheduled_interval', -3);
	END IF;

	IF _auto_scheduler_id IS NOT NULL THEN
		DELETE FROM grape.schedule WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER AND status='NewTask';
		UPDATE grape.auto_scheduler SET
			scheduled_interval=_scheduled_interval,
			dow=_dow,
			days_of_month=_dom,
			day_time=_time,
			run_as_user_id=_run_as_user_id,
			run_with_params=_run_with_params,
			active=_active

			WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	ELSE
		INSERT INTO grape.auto_scheduler (process_id, scheduled_interval, dow, days_of_month, day_time, run_as_user_id, run_with_params, active) 
			VALUES (_process_id, _scheduled_interval, _dow, _dom, _time, _run_as_user_id, _run_with_params, _active)
			RETURNING auto_scheduler_id INTO _auto_scheduler_id;
	END IF;

	PERFORM grape.autoschedule_next(_auto_scheduler_id);

	RETURN grape.api_success('auto_scheduler_id', _auto_scheduler_id);
END; $$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION grape.autoschedule_next(_auto_scheduler_id INTEGER, _now TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP) RETURNS INTEGER AS $$
DECLARE
	_schedule_id INTEGER;
	_rec RECORD;
	_days_of_month_s TEXT[];
	_days_of_month INTEGER[];
	_dow VARCHAR(7);
	_s TEXT;

	_d DATE;

	_every_dom BOOLEAN;
	_every_dow BOOLEAN;

	_last_run TIMESTAMP;
	_time_sched TIMESTAMP;
BEGIN
	SELECT * INTO _rec FROM grape.auto_scheduler WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	IF NOT FOUND THEN
		RETURN -1;
	END IF;
	
	IF _rec.days_of_month = '*' OR _rec.days_of_month = '' OR _rec.days_of_month IS NULL THEN -- every day of the month
		_every_dom := TRUE;
	ELSE
		_every_dom := FALSE;
		_days_of_month := '{}'::INTEGER[];
		_days_of_month_s := string_to_array(_rec.days_of_month, ',');
		FOREACH _s IN ARRAY _days_of_month_s LOOP
			BEGIN
				_days_of_month := array_append(_days_of_month, _s::INTEGER);
			EXCEPTION WHEN OTHERS THEN
			END;
		END LOOP;
	END IF;

	IF _rec.dow = '1111111' OR _rec.dow = '0000000' THEN
		_every_dow := TRUE;
	ELSE
		_every_dow := FALSE;
	END IF;

	SELECT MAX(time_sched) INTO _last_run FROM grape.schedule WHERE auto_scheduler_id=_auto_scheduler_id::INTEGER;
	IF _last_run IS NULL THEN
		_last_run := _now::DATE - '1 day'::INTERVAL; 
	END IF;

	-- find the next day it can run on (it might be today)
	IF _rec.day_time IS NOT NULL THEN -- once a day at time
		_time_sched := ((_last_run::DATE) + '1 day'::INTERVAL) + _rec.day_time; -- initial value
	ELSIF _rec.scheduled_interval IS NOT NULL THEN 
		_time_sched := _last_run + _rec.scheduled_interval;
	END IF;

	IF _every_dom = TRUE AND _every_dow = TRUE THEN -- every day
		IF _rec.day_time IS NOT NULL THEN -- once a day at time
			_time_sched := ((_last_run + '1 day'::INTERVAL)::DATE + _rec.day_time)::TIMESTAMP;
		ELSIF _rec.scheduled_interval IS NOT NULL THEN -- interval
			_time_sched := _last_run::DATE;
			WHILE _time_sched <= _now LOOP
				_time_sched := _time_sched + _rec.scheduled_interval;
			END LOOP;
		END IF;
	ELSIF _every_dom = TRUE AND _every_dow = FALSE THEN -- some days of the week only

		WHILE 
			SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _time_sched)::INTEGER + 1, 1) = '0' 
			OR _time_sched <= _now 
		LOOP
			IF _rec.day_time IS NOT NULL THEN -- run once a day at a specified time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN -- run at interval 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;
		END LOOP;

	ELSIF _every_dom = FALSE AND _every_dow = TRUE THEN -- some days of the month only

		WHILE 
			ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _time_sched)::INTEGER) IS NULL 
			OR _time_sched <= _now 
		LOOP
			IF _rec.day_time IS NOT NULL THEN -- once a day at time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;
		END LOOP;

	ELSIF _every_dom = FALSE AND _every_dow = FALSE THEN
		WHILE 
			ARRAY_POSITION(_days_of_month, EXTRACT('day' FROM _time_sched)::INTEGER) IS NULL 
			OR SUBSTRING(_rec.dow::TEXT, EXTRACT('dow' FROM _time_sched)::INTEGER + 1, 1) = '0' 
			OR _time_sched <= _now 
		LOOP

			IF _rec.day_time IS NOT NULL THEN -- once a day at time
				_time_sched := _time_sched + '1 day'::INTERVAL;
			ELSIF _rec.scheduled_interval IS NOT NULL THEN 
				_time_sched := _time_sched + _rec.scheduled_interval;
			END IF;

		END LOOP;
	END IF;

	INSERT INTO grape.schedule (process_id, time_sched, param, user_id, status, auto_scheduler_id)
		VALUES (_rec.process_id, _time_sched, _rec.run_with_params, _rec.run_as_user_id, 'NewTask', _auto_scheduler_id)
		RETURNING schedule_id INTO _schedule_id;


	RETURN _schedule_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.delete_process_autoschedule(_process_id INTEGER, _auto_scheduler_id INTEGER) RETURNS INTEGER AS $$
DECLARE
BEGIN

	IF grape.check_process_edit_permission(_process_id) THEN
		DELETE FROM grape.auto_scheduler WHERE process_id=_process_id::INTEGER AND auto_scheduler_id=_auto_scheduler_id::INTEGER;
		RETURN 0;
	ELSE
		RETURN -1;
	END IF;

END; $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION grape.api_delete_process_autoschedule(JSONB) RETURNS JSONB AS $$
DECLARE
	_process_id INTEGER;
       	_auto_scheduler_id INTEGER;
	_r INTEGER;
BEGIN

	_process_id := ($1->>'process_id')::INTEGER;
	_auto_scheduler_id := ($1->>'auto_scheduler_id')::INTEGER;

	_r := grape.delete_process_autoschedule(_process_id, _auto_scheduler_id);

	IF _r = -1 THEN
		-- TODO permission denied
	END IF;

	RETURN grape.api_success();
END; $$ LANGUAGE plpgsql

