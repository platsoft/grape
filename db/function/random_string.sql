
/**
 * Generate a random string containing characters 0-9A-Z of length length
 */
CREATE OR REPLACE FUNCTION grape.random_string(length INTEGER) RETURNS TEXT AS 
$$
declare
	chars TEXT[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}';
	result TEXT := '';
	i INTEGER := 0;
BEGIN
	FOR i IN 1 .. length LOOP
		result := result || chars[1+random()*(array_length(chars, 1)-1)];
	END LOOP;
	RETURN result;
END;
$$ LANGUAGE plpgsql;

