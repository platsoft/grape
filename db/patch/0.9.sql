
ALTER TABLE grape.setting ADD COLUMN hidden BOOLEAN DEFAULT FALSE;

ALTER TABLE grape.data_import ADD COLUMN result_table TEXT;
ALTER TABLE grape.data_import ADD COLUMN result_schema TEXT;

ALTER TABLE grape.report ADD COLUMN report_type TEXT;
ALTER TABLE grape.report ADD COLUMN active BOOLEAN DEFAULT TRUE;
ALTER TABLE grape.report ADD COLUMN cache_time INTERVAL;


ALTER TABLE grape.reports_executed ADD COLUMN input_fields JSON;

ALTER TABLE grape.schedule ADD COLUMN progress_completed INTEGER DEFAULT 0;
ALTER TABLE grape.schedule ADD COLUMN progress_total INTEGER DEFAULT 0;

CREATE TABLE grape.session_history(
	session_id text NOT NULL,
	ip_address text,
	user_id integer,
	date_inserted timestamptz,
	last_activity timestamptz,
	date_logout timestamptz,
	CONSTRAINT session_history_pk PRIMARY KEY (session_id)

);
ALTER TABLE grape.session_history ADD CONSTRAINT session_user_fk FOREIGN KEY (user_id) 
	REFERENCES grape."user" (user_id) MATCH FULL;


SELECT grape.set_value('grape_version', '0.9');


