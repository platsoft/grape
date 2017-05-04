
var commander = require('commander');
var fs = require('fs');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Create users on the system, from a CSV file',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	commander
		.option('-f, --file [file]', 'CSV file containing list of users (columns <username>;<email>;<password>;<roles>;<guid>;<fullnames>) ')
		.parse(opts.argv);

	if (!commander.file)
	{
		commander.help();
		cb('Provide an input file');
		return;
	}

	var counter = 0;

	function new_user(obj, cb)
	{
		opts.db.query("SELECT grape.user_save($1)", [obj], function(err, ret) {
			if (err)
			{
				console.log(err);
				cb(err);
			}
			
			var user_save = ret.rows[0].user_save;
			if (user_save.status == 'OK')
			{
				opts.funcs.print_ok("New user " + obj.username + " created with user ID " + user_save.user_id);
			}
			else
			{
				opts.funcs.print_error('Failed to create new user ' + obj.username + ' ' + user_save.message);
			}

			cb(null);
		});
	}


	var file_contents = fs.readFileSync(commander.file, {encoding: 'utf8'});
	var lines = file_contents.split("\n");
	for (var i = 0; i < lines.length; i++)
	{
		var line = lines[i];
		if (line.trim() == '')
			continue;
		var ar = line.split(';');
		if (ar.length < 4)
		{
			var ar = line.split(',');
			if (ar.length < 4)
			{
				cb("Invalid file format. File should contain <username>;<email>;<password>;<roles>;<guid>;<fullnames>");
			}
		}

		if (!ar[4])
			ar[4] = null;
		if (!ar[5])
			ar[5] = ar[0];

		var obj = {
			username: ar[0],
			email: ar[1],
			password: ar[2],
			role_names: ar[3],
			guid: ar[4],
			fullnames: ar[5]
		};

		counter++;
		new_user(obj, function() {
			counter--;
			if (counter <= 0)
				cb(null);
		});
	};

};

module.exports = GrapeCmd;

