

ALTER TABLE grape.service ADD COLUMN username TEXT;
ALTER TABLE grape.service ADD COLUMN description TEXT;
ALTER TABLE grape.service ADD COLUMN endpoint_url TEXT;
ALTER TABLE grape.service ADD COLUMN provides TEXT[];
ALTER TABLE grape.service ADD COLUMN attributes JSONB;
ALTER TABLE grape.service ADD COLUMN protocol TEXT;
ALTER TABLE grape.service ADD COLUMN guid UUID;

