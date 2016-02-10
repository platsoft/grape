
/**
 * Returns a text containing only numbers
 */
CREATE OR REPLACE FUNCTION grape.clean_telephone_number (_tel TEXT) RETURNS TEXT AS $$
        SELECT regexp_replace (_tel, '[^0-9]*' ,'', 'g');
$$ LANGUAGE sql IMMUTABLE;


