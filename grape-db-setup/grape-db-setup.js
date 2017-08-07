#!/usr/bin/env node

var commander = require('commander');

commander
	.description('Load SQL files into a database or stdout')
	.usage('[options] | [directory directory directory ...] | [file file file ...]')
	.option('-d, --dburi [dburi]', 'DB connection string (postgres://user:password@host/dbname)')
	.option('-s, --superdburi [superdburi]', 'Connection string for database creation')
	.option('-c, --create', 'Create the database before attempting to create objects')
	.option('-r, --drop', 'Drop and recreate the database before attempting to create objects')
	.option('-i, --continue', 'Continue processing when an error occurs (by default, processing will stop)')
	.option('-e, --schema [schema]', 'The default schema to use when creating objects (defaults to "public"). If "none" is specified, search_path will not be set')
	.option('-a, --readconfig [config.js]', 'Reads the DBURI from the file provided (loaded as a node module and looking at the dburi export)')
	.parse(process.argv);


var fs = require('fs');
var _ = require('underscore');
var pg = require('pg');
var parse_connection_string = require('pg-connection-string').parse;

var util = require('util');
var path = require('path');

var pc = require(__dirname + '/print_colors.js');

if (commander.args.length == 0)
{
	commander.help();
	process.exit(1);
}

if (commander.dburi && commander.readconfig)
{
	pc.print_err("You cannot set both --dburi and --readconfig settings");
	commander.help();
	process.exit(1);
}

if (commander.readconfig)
{
	// TODO load JSON as well
	var configfile = process.cwd() + '/' + commander.readconfig;

	var config = require(configfile);
	commander.dburi = config.dburi;
}

if (!commander.schema)
	commander.schema = 'public';


var sql_list = [];
var sql_file_list = [];
var directory_list = [];


function load_entry (f, source) 
{
	pc.level++;
	try {
		var realpath = fs.realpathSync(f);
		var fstat = fs.statSync(realpath);
	} catch (e) {
		pc.print_err('No such file: ' + f + ' (defined in ' + source + ')');
		pc.level--;
		if (!(commander['continue']))
			return false;
	}

	if (fstat.isDirectory())
	{
		if (load_directory(realpath) == false)
			return false;
	}
	else if (fstat.isFile())
	{
		var extname = path.extname(realpath);
		if (extname == '.sql')
		{
			if (load_sqlfile(realpath) == false)
				return false;
		}
		else if (extname == '.manifest')
		{
			if (load_manifestfile(realpath) == false)
				return false;
		}
	}
	else
	{
		console.error("Unknown type of file");
	}
	pc.level--;
	return true;
}


function load_directory(dirname)
{
	pc.print_info("Loading directory " + dirname);
	var dir_list = [];

	var files = fs.readdirSync(dirname);
	for (var i = 0; i < files.length; i++) 
	{
		var filename = path.resolve(dirname, files[i]);
		var fstat = fs.statSync(filename);

		if (fstat.isFile()) 
		{
			if (load_entry(filename, dirname) == false)
				return false;
		}
		else if (fstat.isDirectory()) 
		{
			dir_list.push(filename);
		}
	}

	if (dir_list.length != 0) 
	{
		var current_dir = dir_list.shift();
		while (current_dir)
		{
			load_directory(current_dir);
			current_dir = dir_list.shift();
		}
	}

	return true;
}

function load_sqlfile(filename)
{
	var parent_directory = path.dirname(filename);
	pc.print_info("Loading sql file " + filename);

	if (sql_file_list.indexOf(filename) >= 0)
	{
		return;
	}

	sql_file_list.push(filename);

	var data = fs.readFileSync(filename, 'utf8');

	var idx = -1;
	while ((idx = data.indexOf('-- Require:', idx+1)) >= 0)
	{
		var nlidx = data.indexOf("\n", idx);
		var include_filename = data.substring(idx + '-- Require:'.length, nlidx).trim();
		var include_filepath = path.resolve(path.dirname(filename), include_filename);

		pc.level++;
		if (load_entry(include_filepath, filename) == false)
			return false;

		pc.level--;
	}

	var new_data;
	if (commander.schema != 'none')
	{
		new_data = ["SET search_path TO '", commander.schema, "';\n", data].join('');
	}
	else
	{
		new_data = data;
	}

	sql_list.push({ 
		data: new_data,
		filename: filename
	});

	var idx = -1;
	while ((idx = data.indexOf('-- Post:', idx+1)) >= 0)
	{
		var nlidx = data.indexOf("\n", idx);
		var include_filename = data.substring(idx + '-- Post:'.length, nlidx).trim();
		var include_filepath = path.resolve(path.dirname(filename), include_filename);

		pc.level++;
		if (load_entry(include_filepath, filename) == false)
			return false;
		pc.level--;
	}

}

function load_manifestfile(filename)
{
	var parent_directory = path.dirname(filename);
	pc.print_info("Loading manifest file " + filename);

	var check = true;
	
	var data = fs.readFileSync(filename, 'utf8');
	var lines = data.split("\n");
	lines.forEach(function(line) {
		if (check == false)
			return false;

		if (line.indexOf('#') >= 0)
			line = line.substring(0, line.indexOf('#'));

		line = line.trim();

		if (line.trim() != '')
		{
			var mfilename = path.resolve(parent_directory, line);
			if (load_entry(mfilename, filename) == false)
			{
				check = false;
				return false;
			}
		}
	});

	return check;
}

/**
 * connect to superdburi and create dburi
 * cb will only be called on success
 */
function create_database(superdburi, dburi, cb)
{
	var client = null;
	if (superdburi)
		client = new pg.Client(superdburi);
	else
		client = new pg.Client();

	client.connect(function(err) {
		if (err)
		{
			pc.print_err("Error estabilishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');
			process.exit(1);
		}
		else
		{
			if (!dburi)
			{
				pc.print_err('If you want a database to be created (as specified by option -c, --create) you need to provide the database details using the --dburi, -d option');
				process.exit(1);
			}

			if (typeof dburi == 'string')
				var obj = parse_connection_string(dburi);
			else
				var obj = dburi;

			if (!obj.database || !obj.user)
			{
				pc.print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
				process.exit(1);
			}

			client.query(['CREATE DATABASE "', obj.database, '" OWNER "', obj.user, '"'].join(''), 
				function(err, res) {
					if (err)
					{
						pc.print_err("Error during database creation: " + err.toString() + ' (' + err.code + ')');
						process.exit(1);
					}

					client.end();
					cb();
				}
			);
		}
	});

}

/**
 * connect to superdburi and create dburi
 * cb will only be called on success
 */
function drop_database(superdburi, dburi, cb)
{
	var client = null;
	if (superdburi)
		client = new pg.Client(superdburi);
	else
		client = new pg.Client();

	client.connect(function(err) {
		if (err)
		{
			pc.print_err("Error estabilishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');
			process.exit(1);
		}
		else
		{
			if (!dburi)
			{
				pc.print_err('If you want a database to be dropped (as specified by option -r, --drop) you need to provide the database details using the --dburi, -d option');
				process.exit(1);
			}

			if (typeof dburi == 'string')
				var obj = parse_connection_string(dburi);
			else
				var obj = dburi;

			if (!obj.database || !obj.user)
			{
				pc.print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
				process.exit(1);
			}
		
			client.query('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=$1', [obj.database], function(err, result) {

				client.query(['DROP DATABASE "', obj.database, '"'].join(''), 
					function(err, res) {
						if (err)
						{
							pc.print_err("Error during database drop: " + err.toString() + ' (' + err.code + ')');
							process.exit(1);
						}

						client.end();
						cb();
					}
				);
			});
		}
	});

}



function create_objects()
{
	var client = null;
	if (commander.dburi)
	{
		pc.print_info("Connecting to database...");
		client = new pg.Client(commander.dburi);

		client.connect(function(err) {

			if (err)
			{
				console.log();
				pc.print_err("Error connecting to " + commander.dburi + ": " + err.toString() + ' (' + err.code + ')');
				if (err.code == '3D000') // database "pinotage" does not exist
				{
					console.log();
					pc.print_warn('Please ensure your database settings are correct. You can create a database in the following ways:');
					pc.level++;
					pc.print_warn("* Use the createdb command (included in the postgres installation)");
					pc.print_warn("* Connect to the database and issue a 'CREATE DATABASE ' command");
					pc.print_warn("* Provide the -c, --create option to this program");
					console.log();
				}

				process.exit(1);
				return;
			}
			else
			{
				pc.print_ok("Connected");
			}

			next(null, null);
		});
	}
	else
	{
		next(null, null);
	}

	function next(err, result)
	{
		if (err)
		{

			if (commander['continue'])
			{
				pc.level++;
				pc.print_warn(err);
				pc.level--;
			}
			else
			{
				pc.level++;
				pc.print_err(err);
				pc.level--;

				client.end();
				process.exit(1);
				return;
			}
		}
		if (sql_list.length <= 0)
		{
			pc.print_info("DONE");

			if (client)
				client.end();
		}
		else
		{

			var nextfile = sql_list.shift();
			pc.print_info("Creating " + nextfile.filename + " (" + nextfile.data.length + " bytes)");

			if (client)
			{
				client.query(nextfile.data, next);
			}
			else
			{
				console.log('/* CONTENTS OF FILE: ' + nextfile.filename + ' */');
				console.log(nextfile.data);
				console.log();
				next(null, null);
			}
		}
	}


}

pc.print_info("Building list...");

for (var i = 0; i < commander.args.length; i++) 
{
	var f = commander.args[i];
	if (load_entry(f, 'command line') == false)
	{
		sql_list = [];
		break;
	}
}

if (sql_list.length == 0)
{
	pc.print_warn('No SQL files found');

	process.exit(1);
}

if (commander.drop)
{
	drop_database(commander.superdburi, commander.dburi, function() {
		create_database(commander.superdburi, commander.dburi, create_objects);
	});
}
else
{
	if (commander.create)
		create_database(commander.superdburi, commander.dburi, create_objects);
	else
		create_objects();
}

