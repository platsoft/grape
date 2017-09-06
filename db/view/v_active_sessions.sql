
CREATE OR REPLACE VIEW grape.v_active_sessions AS 
	SELECT 
		s.session_id,
		s.ip_address,
		s.date_inserted,
		s.last_activity,
		s.session_origin,
		u.username,
		u.email,
		u.fullnames
	FROM grape."session" s
	JOIN grape."user" u USING (user_id)
	ORDER BY date_inserted DESC;
