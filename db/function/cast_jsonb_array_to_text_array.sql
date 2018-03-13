
/**
 * Convert JSONB text array into Postgres TEXT array
 */
CREATE OR REPLACE FUNCTION grape.cast_jsonb_array_to_text_array (JSONB) RETURNS TEXT[] AS $$
	SELECT array_agg(a) FROM jsonb_array_elements_text($1) a;
$$ LANGUAGE sql IMMUTABLE;

DROP CAST IF EXISTS (JSONB AS TEXT[]);
CREATE CAST (JSONB AS TEXT[]) WITH FUNCTION grape.cast_jsonb_array_to_text_array(JSONB) AS IMPLICIT;


