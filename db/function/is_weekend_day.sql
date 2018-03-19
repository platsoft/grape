
-- returns true if $1 falls on a weekend
CREATE OR REPLACE FUNCTION grape.is_weekend_day(DATE) RETURNS BOOLEAN AS $$
	SELECT extract(dow FROM $1) IN (0,6);
$$ LANGUAGE 'sql' STRICT IMMUTABLE;
