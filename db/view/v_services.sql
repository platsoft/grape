
CREATE OR REPLACE VIEW grape.v_services AS 
	SELECT 
		service_id,
		service_name,
		role,
		shared_secret
	FROM grape.service
	ORDER BY service_name, role;
