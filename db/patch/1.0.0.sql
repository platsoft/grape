

ALTER TABLE grape.process ADD COLUMN function_schema TEXT;
ALTER TABLE grape.process ADD COLUMN process_category TEXT;
ALTER TABLE grape.process ADD COLUMN count_new INTEGER DEFAULT 0;
ALTER TABLE grape.process ADD COLUMN count_completed INTEGER DEFAULT 0;
ALTER TABLE grape.process ADD COLUMN count_error INTEGER DEFAULT 0;
ALTER TABLE grape.process ADD COLUMN count_running INTEGER DEFAULT 0;

ALTER TABLE grape.schedule ADD COLUMN auto_scheduler_id INTEGER;

ALTER TABLE grape.list_query_whitelist ADD COLUMN roles TEXT[] DEFAULT '{all}';

DROP TABLE IF EXISTS grape.auto_scheduler CASCADE;
CREATE TABLE grape.auto_scheduler(
	auto_scheduler_id serial NOT NULL,
	process_id integer,
	scheduled_interval interval,
	dow varchar(7) DEFAULT '1111111',
	days_of_month text DEFAULT '*',
	day_time time,
	run_as_user_id integer,
	run_with_params json,
	active boolean DEFAULT TRUE,
	CONSTRAINT auto_scheduler_pk PRIMARY KEY (auto_scheduler_id)

);
-- ddl-end --
COMMENT ON COLUMN grape.auto_scheduler.dow IS 'days of week represented by 0 and 1; starting on Sunday';
-- ddl-end --
COMMENT ON COLUMN grape.auto_scheduler.days_of_month IS 'Comma separated list of days of month';
-- ddl-end --

DROP TABLE IF EXISTS grape.setting_history CASCADE;
CREATE TABLE grape.setting_history(
	setting_history_id serial NOT NULL,
	setting_name text,
	value text,
	json_value json,
	date_inserted timestamptz,
	user_id integer,
	CONSTRAINT setting_history_pk PRIMARY KEY (setting_history_id)
);

DROP FUNCTION IF EXISTS grape.api_result_error(_message TEXT, _code INTEGER);
DROP FUNCTION IF EXISTS grape.api_error(_message TEXT, _code INTEGER);
DROP FUNCTION IF EXISTS grape.api_error_invalid_input();
DROP FUNCTION IF EXISTS grape.api_error_permission_denied();

ALTER TABLE grape.setting ADD COLUMN description TEXT;
ALTER TABLE grape.setting ADD COLUMN data_type TEXT;

