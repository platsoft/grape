

CREATE OR REPLACE FUNCTION grape.current_user_roles() RETURNS SETOF TEXT AS $$ 
DECLARE
	_role TEXT;
BEGIN
	IF grape.current_user_id() IS NULL THEN
		RETURN NEXT 'guest';
		RETURN NEXT 'any';
	ELSE
		RETURN NEXT 'all';
		FOR _role IN SELECT * FROM grape.get_user_roles(grape.current_user_id()::INTEGER) LOOP
			RETURN NEXT _role;
		END LOOP;
		RETURN NEXT 'any';
	END IF;

END; 
$$ LANGUAGE plpgsql VOLATILE;

-- Returns true if the current user belongs to _role
CREATE OR REPLACE FUNCTION grape.current_user_in_role(_role TEXT) RETURNS BOOLEAN AS $$
	SELECT EXISTS (
		SELECT 1 FROM grape.current_user_roles() role_name
			WHERE (_role='all' OR role_name=_role::TEXT)
		);
$$ LANGUAGE sql VOLATILE;	

-- Returns true if the current user belongs to any of _roles
CREATE OR REPLACE FUNCTION grape.current_user_in_role(_roles TEXT[]) RETURNS BOOLEAN AS $$
	SELECT EXISTS (
		SELECT 1 FROM grape.current_user_roles() role_name
			WHERE ( role_name=ANY(_roles) OR 'all'=ANY(_roles) )
		);
$$ LANGUAGE sql VOLATILE;	


