
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'User management (update password or roles)',
	db: true
};

function update_pw(opts, cb)
{
	opts.db.query("SELECT grape.set_user_password($1, $2, false)", [opts.username, opts.password], function(err, ret) {
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

}

function update_role(opts, cb)
{
	opts.db.query("SELECT grape.add_user_to_access_role($1, $2)", [opts.username, opts.role], function(err, ret) {
		if (err)
		{
			console.log(err);
			cb(err);
		}
		
		opts.funcs.print_ok("Role updated");
		cb(null);

	});


}


function list_users(opts, cb)
{
	var func = opts.funcs;

	opts.db.query('SELECT user_id, username, fullnames, email FROM grape."user" ORDER BY user_id', [], function(err, ret) {
		if (err)
		{
			console.log(err);
			cb(err);
		}
		
		console.log([
				func.align('User ID', 10),
				func.align('Username', 20),
				func.align('Email', 40),
				func.align('Full names', 40)
				].join(''));

		var s = '';
		for (var i = 0; i < 110; i++)
			s = s + '-';
		console.log(s);


		for (var i = 0; i < ret.rows.length; i++)
		{
			var row = ret.rows[i];
			console.log([
					func.align(row.user_id, 10),
					func.align(row.username, 20),
					func.align(row.email, 40),
					func.align(row.fullnames, 40)
					].join(''));
		}
		
		cb(null);

	});
}


// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {

	//console.log(opts.argv);
	switch (opts.argv[2])
	{
		case 'list':
			list_users(opts, cb);
			break;
		case 'password':
			if (!opts.argv[3] || !opts.argv[4])
			{
				cb("Provide username and new password");
			}
			opts.username = opts.argv[3];
			opts.password = opts.argv[4];
			update_pw(opts, cb);
			break;
		case 'add_role':
			if (!opts.argv[3] || !opts.argv[4])
			{
				cb("Provide username and new role");
			}
			opts.username = opts.argv[3];
			opts.role= opts.argv[4];
			update_role(opts, cb);
			break;

		default:
			console.log("Usage: grape-manage user [command] [options]");
			console.log("Valid commands are: list, password, add_role");
			cb("Invalid options provided");
			break;
	}

};

module.exports = GrapeCmd;

