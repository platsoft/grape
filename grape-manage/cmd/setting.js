
var commander = require('commander');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'View and change settings',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	var func = opts.funcs;
	commander
		.option('-l, --list', 'List all settings')
		.option('-s, --setting [setting]', 'Setting to view/change')
		.option('-v, --value [value]', 'If provided with a setting name, setting will be updated')
		.parse(opts.argv);

	if (!commander.list && !commander.setting)
	{
		commander.help();
		cb('Invalid options provided');
		return;
	}

	if (commander.list)
	{
		opts.db.query("SELECT name, value, hidden, description, data_type FROM grape.setting ORDER BY name", [], function(err, ret) {
			if (err)
			{
				console.log(err);
				cb(err);
			}
			
			console.log([
					func.align('Name', 30),
					func.align('Value', 50),
					func.align('Hidden', 7),
					func.align('Type', 7),
					func.align('Description', 40)
					].join(''));

			var s = '';
			for (var i = 0; i < 110; i++)
				s = s + '-';
			console.log(s);


			for (var i = 0; i < ret.rows.length; i++)
			{
				var row = ret.rows[i];
				console.log([
						func.align(row.name, 30),
						func.align(row.value, 50),
						func.align((row.hidden ? 'true' : 'false'), 7),
						func.align(row.data_type, 7),
						func.align(row.description, 40)
						].join(''));
			}


			cb(null);
		});


	}
	else if (commander.value)
	{
		opts.db.query("SELECT grape.set_value($1, $2)", [commander.setting, commander.value], function(err, ret) {
			if (err)
			{
				console.log(err);
				cb(err);
			}
			
			console.log('Value of ' + commander.setting + ' changed to ' + ret.rows[0].set_value);

			cb(null);
		});

	}
	else
	{
		opts.db.query("SELECT value FROM grape.setting WHERE name=$1", [commander.setting], function(err, ret) {
			if (err)
			{
				console.log(err);
				cb(err);
			}
			if (ret.rows.length < 1)
				console.log("Unknown setting " + commander.setting);
			else
				console.log(ret.rows[0].value);

			cb(null);
		});

	}

};

module.exports = GrapeCmd;

