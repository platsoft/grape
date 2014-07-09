
/**
 * Calculates the difference in months between 2 dates
 */
CREATE OR REPLACE FUNCTION grape.month_diff(DATE, DATE) RETURNS INTEGER AS $$
	SELECT ((DATE_PART('year', $2::DATE)::INT - DATE_PART('year', $1::DATE)::INT) * 12) + 
                                (DATE_PART('month', $2::DATE)::INT - DATE_PART('month', $1::DATE)::INT);
$$ LANGUAGE SQL;

