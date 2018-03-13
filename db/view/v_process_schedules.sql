
DROP VIEW IF EXISTS grape.v_process_schedules;
CREATE OR REPLACE VIEW grape.v_process_schedules AS 
	SELECT
		s.schedule_id,
		s.process_id,
		s.time_sched,
		s.time_started,
		s.time_ended,
		s.pid,
		s.param,
		grape.username(s.user_id) AS username,
		s.logfile,
		s.status,
		s.progress_completed,
		s.progress_total,
		CASE 
			WHEN s.progress_total = 0 THEN 0
			ELSE ROUND((s.progress_completed*1.0) / s.progress_total * 100.0, 2)
		END AS perc_complete,
		s.auto_scheduler_id
	FROM 
		grape.schedule s
		;

