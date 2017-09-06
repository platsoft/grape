
CREATE OR REPLACE VIEW grape.v_process_definitions AS 
	SELECT 
		p.*,
		(SELECT json_agg(a.s) FROM
			(SELECT (to_jsonb(b) || jsonb_build_object('run_as_user', grape.username(run_as_user_id))) s FROM
				grape.auto_scheduler b
			WHERE process_id=p.process_id) a) AS auto_scheduler,
		(SELECT json_agg(process_role) FROM grape.process_role WHERE process_id=p.process_id) AS process_role
		FROM grape.process p
	;

