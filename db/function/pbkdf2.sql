
CREATE SCHEMA IF NOT EXISTS pbkdf2;

CREATE OR REPLACE FUNCTION pbkdf2.algorithm_length(_algo TEXT) RETURNS INTEGER AS $$
	SELECT LENGTH(DIGEST('', _algo));
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION pbkdf2.xor_bytea(_a BYTEA, _b BYTEA) RETURNS BYTEA AS $$
DECLARE
	_m INTEGER;
	_ret BYTEA;
BEGIN
	_m := LEAST(LENGTH(_a), LENGTH(_b));
	_ret := SUBSTRING(_a FROM 1 FOR _m);
	FOR k IN 1 .. _m LOOP
		_ret := SET_BYTE(_ret, k - 1, GET_BYTE(_a, k - 1) # GET_BYTE(_b, k - 1));
	END LOOP;
	RETURN _ret;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pbkdf2.int_to_bytea (_int INTEGER) RETURNS BYTEA AS $$
	SELECT DECODE(LPAD(TO_HEX(_int), 2, '0'), 'hex');
$$ LANGUAGE sql;
	
CREATE OR REPLACE FUNCTION pbkdf2.lpad_bytea(_bytes BYTEA, _length INTEGER, _pad_with BYTEA) RETURNS BYTEA AS $$
DECLARE
	_ret BYTEA;
BEGIN
	IF LENGTH(_bytes) >= _length THEN
		RETURN _bytes;
	END IF;

	_ret := DECODE(LPAD('', (_length - LENGTH(_bytes)) * 2, '0'), 'hex') || _bytes;
	RETURN _ret;
END; $$ LANGUAGE plpgsql ;

/*
 * RFC8018 Section 5.2 https://tools.ietf.org/html/rfc8018#section-5.2
 */
CREATE OR REPLACE FUNCTION pbkdf2.pbkdf2 
(
	_algo TEXT, /* algorithm to use (sha256, sha1, etc) */
	_password TEXT, /* password */
	_salt TEXT, /* base 64'd salt */
	_count INTEGER, /* iteration count, a positive integer */
	_dklen INTEGER /* intended length in octets of the derived key, a positive integer, at most (2^32 - 1) * hLen */
) RETURNS BYTEA AS $$
DECLARE 
	_hlen INTEGER;
	_blocks INTEGER;
	_i INTEGER := 1;
	_j INTEGER;

	_u1 BYTEA;
	_uj BYTEA;

	_ret BYTEA;

	_bsalt BYTEA;

BEGIN

	_hlen := pbkdf2.algorithm_length(_algo);

	_blocks := CEIL(_dklen::REAL / _hlen::REAL);

	IF _dklen > ((2^31 - 1) * _hlen) THEN
		RAISE EXCEPTION 'dkLen is too large! Maximum allowed is %', ((2^31 - 1) * _hlen);
	END IF;

	_bsalt := DECODE(_salt, 'base64')::BYTEA;

	-- _r := _dklen - (_blocks - 1) * _hlen;

	FOR _i IN 1 .. _blocks LOOP

		_u1 := HMAC(
			_bsalt::BYTEA || pbkdf2.lpad_bytea(pbkdf2.int_to_bytea(_i), 4, E'\\000'::BYTEA),  -- pack i into a 32bit integer array
			_password::BYTEA, 
			_algo);
	
		_uj := _u1;

		FOR _j IN 2 .. _count LOOP
			_uj := HMAC(_uj, _password::BYTEA, _algo);
			_u1 := pbkdf2.xor_bytea(_u1, _uj);
		END LOOP;

		IF _ret IS NULL THEN
			_ret := _u1;
		ELSE
			_ret := _ret || _u1;
		END IF;
	END LOOP;

	RETURN SUBSTRING(_ret, 1, _dklen);
END $$ LANGUAGE plpgsql;

/*
CREATE OR REPLACE FUNCTION pbkdf2.test_pbkdf2(
	_algo TEXT, -- algorithm to use (sha256, sha1, etc) 
	_password TEXT, -- password 
	_salt TEXT, -- base 64'd salt 
	_count INTEGER, -- iteration count, a positive integer 
	_dklen INTEGER,
	_expected TEXT) RETURNS INTEGER AS $$
DECLARE
	_ret BYTEA;
	_s TEXT;
BEGIN


	_ret := pbkdf2.pbkdf2(_algo, _password, encode(_salt::BYTEA, 'base64'), _count, _dklen);
	_s := encode(_ret::BYTEA, 'hex');
	RAISE NOTICE 'Expected: %', _expected;
	RAISE NOTICE 'Result:   %', _s;

	RETURN 1;
END; $$ LANGUAGE plpgsql;

SELECT pbkdf2.test_pbkdf2('sha1', 'password', 'salt', 1, 20,  '0c60c80f961f0e71f3a9b524af6012062fe037a6');
SELECT pbkdf2.test_pbkdf2('sha1', 'password', 'salt', 2, 20,  'ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957');
SELECT pbkdf2.test_pbkdf2('sha1', 'password', 'salt', 4096, 20,  '4b007901b765489abead49d926f721d065a429c1');
SELECT pbkdf2.test_pbkdf2('sha1', 'passwordPASSWORDpassword', 'saltSALTsaltSALTsaltSALTsaltSALTsalt', 4096, 25, '3d2eec4fe41c849b80c8d83662c0e44a8b291a964cf2f07038');
SELECT pbkdf2.test_pbkdf2('sha1', 'password', 'salt', 16777216, 20, 'eefe3d61cd4da4e4e9945b3d6ba2158c2634e984');
*/

