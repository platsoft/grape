
DROP VIEW IF EXISTS grape.v_active_users;
CREATE OR REPLACE VIEW grape.v_active_users AS
	SELECT 
		u.user_id, 
		u.username, 
		u.email, 
		u.fullnames, 
		u.employee_guid, 
		(SELECT array_agg(g) FROM grape.get_user_roles(u.user_id) g) AS role_names,
		(SELECT array_agg(g) FROM grape.get_user_assigned_roles(u.user_id) g) AS assigned_role_names
	FROM grape."user" u 
		JOIN grape.user_role ur USING (user_id) 
	WHERE u.active=TRUE 
	GROUP BY u.user_id
	ORDER BY u.username;

