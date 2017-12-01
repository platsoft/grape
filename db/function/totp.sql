
-- Based on https://gist.github.com/enzoh/76b127bd58dd16d4b5f0

CREATE OR REPLACE FUNCTION grape.generate_totp(_key TEXT) RETURNS TEXT AS $$
DECLARE
	_counter BIGINT;
	_buf BYTEA;
	_byte INTEGER;
	_hash BYTEA;
	_secret BYTEA;
	i INTEGER;
	_code INTEGER;
BEGIN
	_counter := FLOOR(EXTRACT('epoch' FROM NOW()) / 30);
	_secret := DECODE(_key, 'escape');

	_buf = E'\\x0000000000000000';

	FOR i IN 0..7 LOOP
		_byte := _counter::BIT(8)::INTEGER;
		_buf := SET_BYTE(_buf, 7 - i, _byte);
		_counter := _counter >> 8;
	END LOOP;
	
	_hash := HMAC(_buf::BYTEA, _secret, 'SHA1');

	i := GET_BYTE(_hash, 19) & 15;

	_code := (((GET_BYTE(_hash, i + 0) & 127) << 24) |
			((GET_BYTE(_hash, i + 1) & 255) << 16)|
			((GET_BYTE(_hash, i + 2) & 255) << 08)|
			((GET_BYTE(_hash, i + 3) & 255) << 00)) % 1000000;

	RETURN LPAD(_code::TEXT, 6, '0');

END; $$ LANGUAGE plpgsql;


