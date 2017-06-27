
CREATE OR REPLACE VIEW grape.v_active_users AS
	SELECT 
		u.user_id, 
		u.username, 
		u.email, 
		u.fullnames, 
		u.employee_guid, 
		array_agg(ur.role_name) roles 
	FROM grape."user" u 
		JOIN grape.user_role ur USING (user_id) 
	WHERE u.active=TRUE 
	GROUP BY u.user_id
	ORDER BY u.username;

