
var commander = require('commander');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Lists all users in the system',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
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

};

module.exports = GrapeCmd;

