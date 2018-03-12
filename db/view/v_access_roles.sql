
DROP VIEW IF EXISTS grape.v_access_roles;
CREATE OR REPLACE VIEW grape.v_access_roles AS 
	SELECT 
		ar.role_name,
		(SELECT array_agg(g) FROM grape.get_role_roles(ar.role_name) g) AS membership,
		(SELECT array_agg(g) FROM grape.get_role_assigned_roles(ar.role_name) g) AS assigned_roles
	FROM 
		grape.access_role ar;

