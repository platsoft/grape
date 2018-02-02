
CREATE OR REPLACE VIEW grape.v_users AS
	SELECT u.user_id,
       		u.username,
		u.email,
		u.fullnames,
		u.active,
		u.employee_guid AS guid,
		u.employee_info,
		pg_role,
		u.auth_info->>'totp_status' AS totp_status,
		u.auth_info->>'auth_server' AS auth_server,
		u.auth_info->>'mobile_status' AS mobile_status,
		ur.role_names
	FROM grape.user u
	LEFT JOIN (
		SELECT 
			user_id, 
			array_agg(role_name) AS role_names
		FROM grape.user_role
		GROUP BY user_id
	) ur USING (user_id);
