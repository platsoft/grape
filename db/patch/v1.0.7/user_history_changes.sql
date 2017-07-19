
ALTER TABLE grape.user_history ALTER COLUMN data TYPE JSONB USING data::JSONB;
ALTER TABLE grape.user_history ALTER COLUMN date_inserted TYPE TIMESTAMPTZ;


