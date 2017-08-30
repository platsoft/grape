
var commander = require('commander');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Change a user\'s password',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	commander
		.option('-u, --username [username]', 'Username')
		.option('-p, --password [password]', 'Password')
		.parse(opts.argv);

	if (!commander.username || !commander.password)
	{
		commander.help();
		cb('Provide a username and password');
		return;
	}

	opts.db.query("SELECT grape.set_user_password($1, $2, false)", [commander.username, commander.password], function(err, ret) {
		if (err)
		{
			console.log(err);
			cb(err);
		}
		
		var status = ret.rows[0].set_user_password;
		if (status === true)
		{
			opts.funcs.print_ok("Password updated");
			cb(null);
		}
		else
		{
			cb("Error");
		}

	});

};

module.exports = GrapeCmd;

