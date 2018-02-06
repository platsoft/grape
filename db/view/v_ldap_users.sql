

CREATE OR REPLACE VIEW grape.v_ldap_users AS SELECT 
	CONCAT(
		grape.get_value('ldap_username_field', 'uid'), '=', username, ',', 
		grape.get_value('ldap_users_dn', 'ou=Users,o=platsoft')
	) AS dn,
	username AS "uid",
	username AS "cn",
	email AS "mail",
	fullnames AS "fullnames",
	employee_guid,
	active,
	password
	FROM grape."user" WHERE active=true;

