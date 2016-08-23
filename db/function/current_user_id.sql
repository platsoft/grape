
CREATE OR REPLACE FUNCTION current_user_id() RETURNS INTEGER AS $$ 
BEGIN 
	RETURN current_setting('grape.user_id')::INTEGER; 
EXCEPTION WHEN OTHERS THEN 
	RETURN NULL; 
END; $$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION grape.current_user_id() RETURNS INTEGER AS $$ 
BEGIN 
	RETURN current_setting('grape.user_id')::INTEGER; 
EXCEPTION WHEN OTHERS THEN 
	RETURN NULL; 
END; $$ LANGUAGE plpgsql VOLATILE;


