
-- returns true if $1 falls on a weekend
CREATE OR REPLACE FUNCTION grape.is_weekend_day(DATE) RETURNS BOOLEAN AS $$
	SELECT CASE EXTRACT(dow FROM $1) 
		WHEN 0 THEN TRUE 
		WHEN 6 THEN TRUE 
		ELSE FALSE 
	END;
$$ LANGUAGE 'sql' STRICT IMMUTABLE;

