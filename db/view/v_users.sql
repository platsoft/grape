
DROP VIEW IF EXISTS grape.v_users;
CREATE OR REPLACE VIEW grape.v_users AS
	SELECT u.user_id,
       		u.username,
		u.email,
		u.fullnames,
		u.active,
		u.employee_guid AS guid,
		u.employee_info,
		u.auth_info->>'totp_status' AS totp_status,
		u.auth_info->>'auth_server' AS auth_server,
		u.auth_info->>'mobile_status' AS mobile_status,
		(SELECT array_agg(g) FROM grape.get_user_roles(u.user_id) g) AS role_names,
		(SELECT array_agg(g) FROM grape.get_user_assigned_roles(u.user_id) g) AS assigned_role_names
	FROM grape.user u
		ORDER BY
		       	u.active DESC,	
			u.username;
