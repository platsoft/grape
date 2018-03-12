
SELECT grape.set_value('grape_version', '1.1.3');

ALTER TABLE grape."user" ADD COLUMN preferences JSONB DEFAULT '{}';
ALTER TABLE grape."user" DROP COLUMN pg_role;

DROP FUNCTION IF EXISTS grape.session_insert(JSON);

CREATE TABLE grape.access_role_role(
	parent_role_name text,
	child_role_name text,
	CONSTRAINT access_role_role_pk PRIMARY KEY (parent_role_name,child_role_name)
);
-- ddl-end --
COMMENT ON TABLE grape.access_role_role IS 'Table for access roles that belongs to other access roles';
ALTER TABLE grape.access_role_role ADD CONSTRAINT gar_parent_role_name_access_role_fk FOREIGN KEY (parent_role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE grape.access_role_role ADD CONSTRAINT gar_child_role_access_role_fk FOREIGN KEY (child_role_name)
REFERENCES grape.access_role (role_name) MATCH FULL
ON DELETE NO ACTION ON UPDATE NO ACTION;

SELECT grape.table_permissions_add('grape', '{v_access_roles}'::TEXT[], 'admin', 'SELECT');

