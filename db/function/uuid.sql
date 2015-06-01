
-- a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11
CREATE OR REPLACE FUNCTION grape.generate_uuid() RETURNS uuid AS $$
DECLARE
	_dbname TEXT;
	chars TEXT[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F}';
	result TEXT := '';
	i INTEGER;
BEGIN
	i := 0;

	FOR i IN 1 .. 32 LOOP
		result := result || chars[1+random()*(array_length(chars, 1)-1)];
	END LOOP;
	
	RETURN result::UUID;
END; $$ LANGUAGE plpgsql;


