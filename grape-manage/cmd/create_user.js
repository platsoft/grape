
var commander = require('commander');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Create a new user on the system',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	commander
		.option('-u, --username [username]', 'Username')
		.option('-p, --password [password]', 'Password')
		.option('-g, --guid [guid]', 'Employee GUID')
		.option('-r, --roles <list>', 'Roles')
		.option('-e, --email [email]', 'Email address')
		.parse(opts.argv);

	if (!commander.username)
	{
		commander.help();
		cb('Provide a username');
		return;
	}

	var obj = {
		username: commander.username,
	};

	if (commander.password)
		obj.password = commander.password;

	if (commander.guid)
		obj.employee_guid = commander.guid;
	
	if (commander.email)
		obj.email = commander.email;
	
	if (commander.roles)
		obj.role_names = commander.roles;


	opts.db.query("SELECT grape.user_save($1)", [obj], function(err, ret) {
		if (err)
		{
			console.log(err);
			cb(err);
		}
		
		var user_save = ret.rows[0].user_save;
		if (user_save.status == 'OK')
		{
			opts.funcs.print_ok("New user " + commander.username + " created with user ID " + user_save.user_id);
			cb(null);
		}
		else
		{
			cb(user_save.message);
		}

	});

};

module.exports = GrapeCmd;

