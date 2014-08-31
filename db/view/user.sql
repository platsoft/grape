CREATE OR REPLACE VIEW grape.user_access_role AS
	SELECT u.*, ur.role_names
	FROM grape.user u
	LEFT JOIN (
		SELECT user_id, array_agg(role_name) role_names
		FROM grape.user_role
		GROUP BY user_id
	) ur USING(user_id);
