
var commander = require('commander');

commander
	.usage('[options] <config.js>')
	.option('-r, --recreate', 'Drop and recreate database')
	.parse(process.argv);


var fs = require('fs');
var _ = require('underscore');
var pg = require('pg');
var util = require('util');
var grape_db_dir = fs.realpathSync(__dirname + '/../db/');

var config_file = fs.realpathSync(commander.args[0]);
console.log("Loading config.js from " + config_file);
var config = require(config_file);

var Client = pg.Client;


function do_database_definitions()
{
	var app_db_dir = false;
	var app_db_dirs = [];

	if (config.db_definition)
	{
		if (!util.isArray(config.db_definition))
			app_db_dirs.push(config.db_definition);
		else
			app_db_dirs = config.db_definition;
		for (var i = 0; i < app_db_dirs.length; i++)
		{
			app_db_dir = fs.realpathSync(app_db_dirs[i]);
			console.log("Loading application DB files from " + app_db_dir);
		}
	}

	console.log("Loading Grape DB files from " + grape_db_dir);

	//try to connect to the database
	var client = new Client(config.dburi);

	client.connect(function(err) {

		if (err)
		{
			var dbportstring = '';
			if (config.dburi.port)
				dbportstring = ' -p ' + config.dburi.port + ' ';

			console.log("Error connecting to database: " + err.toString());
			if (err.code == '28000')
			{
				console.log("You need to create database role first:  psql " + dbportstring + " postgres postgres -c 'CREATE ROLE " + config.dburi.user + " WITH LOGIN SUPERUSER;'");
			}
			else if (err.code == '3D000')
			{
				console.log("You need to create the database first:  psql postgres postgres -c 'CREATE DATABASE " + config.dburi.database + " OWNER " + config.dburi.user + ";'");
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
					console.log("DUPLICATE OBJECT: " + err.toString());
					console.log("Run this script with the -r option to force a recreate on the database");
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
			client.query("SET search_path TO 'public';" + nextfile.data, next);
		}

		client.query("SET search_path TO 'public'", function(err, result) {
			if (err) return rollback(client);

			client.query('BEGIN', function(err, result) {
				if (err) return rollback(client);
				loadsqlfiles(grape_db_dir + '/schema');
				loadsqlfiles(grape_db_dir + '/function');
				loadsqlfiles(grape_db_dir + '/data');

				for (var i = 0; i < app_db_dirs.length; i++)
				{
					app_db_dir = app_db_dirs[i];
					loadsqlfiles(app_db_dir + '/schema');
					loadsqlfiles(app_db_dir + '/function');
					loadsqlfiles(app_db_dir + '/data');
				}

				next(null, null);
			});
		});
	});
}

if (commander.recreate == true)
{
	console.log("Recreating database");
	var s_dburi = _.clone(config.dburi);
	s_dburi.user = 'postgres';
	s_dburi.database = 'postgres';
	var s_client = new Client(s_dburi);

	s_client.connect(function(err) {
		if (err)
		{
			console.log("Error connecting to host with user postgres while trying to re-create the database");
			process.exit(2);
			return;
		}
		
		console.log("Terminating backends");
		s_client.query('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=$1', [config.dburi.database], function(err, result) {
			if (err) 
			{
				console.log("ERROR: ", err);
				process.exit(2);
				return;
			}
			console.log("Dropping database");
			s_client.query('DROP DATABASE "' + config.dburi.database + '"', function(err, result) {
				s_client.query('CREATE DATABASE "' + config.dburi.database + '" OWNER "' + config.dburi.user + '"', function(err, result) { 
					do_database_definitions();
				});
			});
		});
	});
}
else
{
	do_database_definitions();
}

