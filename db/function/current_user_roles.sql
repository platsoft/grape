

CREATE OR REPLACE FUNCTION grape.current_user_roles() RETURNS SETOF TEXT AS $$ 
	SELECT role_name FROM grape.user_role WHERE user_id=grape.current_user_id()::INTEGER; 
$$ LANGUAGE sql VOLATILE;


