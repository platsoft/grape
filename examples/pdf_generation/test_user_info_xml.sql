
/**
 * Generates XML for user_id
 */
CREATE OR REPLACE FUNCTION generate_user_xml(_user_id INTEGER) RETURNS TEXT AS $$
DECLARE
	_record RECORD;
	_xml TEXT := '';

BEGIN
	-- UNSAFE
	SELECT * INTO _record FROM grape."user" WHERE user_id=_user_id::INTEGER;

	_xml := CONCAT(_xml, '<user>');

	_xml := CONCAT(_xml, '<username>', _record.username, '</username>');

	_xml := CONCAT(_xml, '</user>');

	RETURN _xml;
END; $$ LANGUAGE plpgsql;


