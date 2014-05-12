
if (process.argv.length != 3)
{
	console.log("Usage: " + process.argv[0] + " [config.js]");
	return;
}

var fs = require('fs');
var pg = require('pg');
var util = require('util');
var grape_db_dir = fs.realpathSync(__dirname + '/../db/');

var config_file = fs.realpathSync(process.argv[2]);
console.log("Loading config.js from " + config_file);
var config = require(config_file);


var app_db_dir = false;

if (config.db_definition)
{
	app_db_dir = fs.realpathSync(config.db_definition);
	console.log("Loading application DB files from " + app_db_dir);
}

console.log("Loading Grape DB files from " + grape_db_dir);

//try to connect to the database
var Client = pg.Client;
var client = new Client(config.dburi);

client.connect(function(err) {

	if (err)
	{
		console.log("Error connecting to database: " + err.toString());
		if (err.code == '28000')
		{
			console.log("You need to create database role first:  CREATE ROLE " + config.dburi.user + " WITH LOGIN SUPERUSER;");
		}
		else if (err.code == '3D000')
		{
			console.log("You need to create the database first:  CREATE DATABASE " + config.dburi.database + " OWNER " + config.dburi.user + ";");
		}
		else
		{
			console.log(util.inspect(err));
		}
		return;
	}

	function rollback(client) {
		client.query('ROLLBACK', function() {
			client.end();
		});
	};

	var sql_list = [];

	function loadsqlfiles(dirname) 
	{
		if (dirname[dirname.length - 1] != '/') dirname += '/';

		if (!fs.existsSync(dirname))
			return;

		var dir_list = [];
		var files = fs.readdirSync(dirname);
		for (var i = 0; i < files.length; i++) 
		{
			var file = files[i];
			var fstat = fs.statSync(dirname + file);
			if (fstat.isFile()) 
			{
				var ar = file.split('.');
				if (ar[ar.length - 1] == 'sql') 
				{
					var data = fs.readFileSync(dirname + file, 'utf8');
					data = data.replace(/^\uFEFF/, '');
					sql_list.push({ 
						data: data,
						filename: dirname + file
					});
				}
			}
			else if (fstat.isDirectory()) 
			{
				dir_list.push(dirname + '/' + file);
			}
		}
		if (dir_list.length != 0) {
			var current_dir = dir_list.shift();
			while (current_dir)
			{
				loadsqlfiles(current_dir);
				current_dir = dir_list.shift();
			}
		}
	}

	function next(err, result)
	{
		if (err)
		{
			if (err.code == '23505' || err.code == '42P06')
			{
				console.log("ERROR: Looks like this database is already populated. You can recreate it with the following command: ");
				console.log("echo 'DROP DATABASE " + config.dburi.database + "; " + "CREATE DATABASE " + config.dburi.database + " OWNER " + config.dburi.user + "; ' | psql postgres postgres");
			}
			else
			{
				console.log("ERROR (" + err.code + "): " + err );
				console.log(util.inspect(err));
			}
			client.end();
			process.exit(1);
			return;
		}
		if (sql_list.length <= 0)
		{
			console.log("DONE");
			client.query('COMMIT');
			client.end();
			process.exit(0);
			return;
		}

		var nextfile = sql_list.shift();
		console.log("Creating " + nextfile.filename + "(" + nextfile.data.length + " bytes)");
		client.query(nextfile.data, next);
	}

	client.query('BEGIN', function(err, result) {
		if (err) return rollback(client);
		loadsqlfiles(grape_db_dir + '/schema');
		loadsqlfiles(grape_db_dir + '/function');
		loadsqlfiles(grape_db_dir + '/data');

		if (app_db_dir)
		{
			loadsqlfiles(app_db_dir + '/schema');
			loadsqlfiles(app_db_dir + '/function');
			loadsqlfiles(app_db_dir + '/data');
		}

		next(null, null);
	});

});


