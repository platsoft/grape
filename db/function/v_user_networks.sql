
CREATE OR REPLACE VIEW grape.v_user_networks AS
	SELECT 
		u.user_id, 
		u.username, 
		n.network_id, 
		n.description, 
		n.address 
	FROM 
		grape.user_network un 
		JOIN grape.network n USING (network_id) 
		JOIN grape."user" u USING (user_id)
	ORDER BY u.username;

