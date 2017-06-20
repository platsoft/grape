

CREATE OR REPLACE FUNCTION grape.current_user_roles() RETURNS SETOF TEXT AS $$ 
	SELECT role_name FROM grape.user_role WHERE user_id=grape.current_user_id()::INTEGER
	UNION
	SELECT 'all'; 
$$ LANGUAGE sql VOLATILE;

-- Returns true if the current user belongs to _role
CREATE OR REPLACE FUNCTION grape.current_user_in_role(_role TEXT) RETURNS BOOLEAN AS $$
	SELECT EXISTS (
		SELECT 1 FROM grape.user_role 
			WHERE user_id=grape.current_user_id()::INTEGER 
				AND (_role='all' OR role_name=_role::TEXT)
		);
$$ LANGUAGE sql VOLATILE;	

-- Returns true if the current user belongs to any of _roles
CREATE OR REPLACE FUNCTION grape.current_user_in_role(_roles TEXT[]) RETURNS BOOLEAN AS $$
	SELECT EXISTS (
		SELECT 1 FROM grape.user_role 
			WHERE user_id=grape.current_user_id()::INTEGER 
				AND ( role_name=ANY(_roles) OR 'all'=ANY(_roles) )
		);
$$ LANGUAGE sql VOLATILE;	


