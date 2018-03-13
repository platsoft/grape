
/**
 * Calculates the difference between 2 dates in years
 */
CREATE OR REPLACE FUNCTION grape.year_diff (_d1 DATE, _d2 DATE) RETURNS NUMERIC AS $$
	SELECT ROUND((_d2::DATE - _d1::DATE) / 365.0, 2);
$$ LANGUAGE SQL IMMUTABLE;



