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
	.parse(process.argv);


var fs = require('fs');
var _ = require('underscore');
var pg = require('pg');
var parse_connection_string = require('pg-connection-string').parse;

var util = require('util');
var path = require('path');
var colors = require('colors');

if (commander.args.length == 0)
{
	commander.help();
	process.exit(1);
}

if (!commander.schema)
	commander.schema = 'public';

var level = 0;

function print_info (str) { console.error("  ".repeat(level) + colors.blue(str)); }
function print_ok (str) { console.error("  ".repeat(level) + colors.green(str)); }
function print_warn (str) { console.error("  ".repeat(level) + colors.yellow(str)); }
function print_err (str) { console.error("  ".repeat(level) + colors.red(str)); }

var sql_list = [];
var sql_file_list = [];
var directory_list = [];


function load_entry (f, source) 
{
	level++;
	try {
		var realpath = fs.realpathSync(f);
		var fstat = fs.statSync(realpath);
	} catch (e) {
		print_err('No such file: ' + f + ' (defined in ' + source + ')');
		level--;
		return;
	}

	if (fstat.isDirectory())
	{
		load_directory(realpath);
	}
	else if (fstat.isFile())
	{
		var extname = path.extname(realpath);
		if (extname == '.sql')
		{
			load_sqlfile(realpath);
		}
		else if (extname == '.manifest')
		{
			load_manifestfile(realpath);
		}
	}
	else
	{
		console.error("Unknown type of file");
	}
	level--;
}


function load_directory(dirname)
{
	print_info("Loading directory " + dirname);
	var dir_list = [];

	var files = fs.readdirSync(dirname);
	for (var i = 0; i < files.length; i++) 
	{
		var filename = path.resolve(dirname, files[i]);
		var fstat = fs.statSync(filename);

		if (fstat.isFile()) 
		{
			load_entry(filename, dirname);
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

}

function load_sqlfile(filename)
{
	var parent_directory = path.dirname(filename);
	print_info("Loading sql file " + filename);

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

		level++;
		load_entry(include_filepath, filename);
		level--;
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

		level++;
		load_entry(include_filepath, filename);
		level--;
	}

}

function load_manifestfile(filename)
{
	var parent_directory = path.dirname(filename);
	print_info("Loading manifest file " + filename);
	
	var data = fs.readFileSync(filename, 'utf8');
	var lines = data.split("\n");
	lines.forEach(function(line) {
		if (line.indexOf('#') >= 0)
			line = line.substring(0, line.indexOf('#'));

		line = line.trim();

		if (line.trim() != '')
		{
			var mfilename = path.resolve(parent_directory, line);
			load_entry(mfilename, filename);
		}
	});
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
			print_err("Error estabilishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');
			process.exit(1);
		}
		else
		{
			if (!dburi)
			{
				print_err('If you want a database to be created (as specified by option -c, --create) you need to provide the database details using the --dburi, -d option');
				process.exit(1);
			}

			var obj = parse_connection_string(dburi);
			if (!obj.database || !obj.user)
			{
				print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
				process.exit(1);
			}

			client.query(['CREATE DATABASE "', obj.database, '" OWNER "', obj.user, '"'].join(''), 
				function(err, res) {
					if (err)
					{
						print_err("Error during database creation: " + err.toString() + ' (' + err.code + ')');
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
			print_err("Error estabilishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');
			process.exit(1);
		}
		else
		{
			if (!dburi)
			{
				print_err('If you want a database to be dropped (as specified by option -r, --drop) you need to provide the database details using the --dburi, -d option');
				process.exit(1);
			}

			var obj = parse_connection_string(dburi);
			if (!obj.database || !obj.user)
			{
				print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
				process.exit(1);
			}

			client.query(['DROP DATABASE "', obj.database, '"'].join(''), 
				function(err, res) {
					if (err)
					{
						print_err("Error during database drop: " + err.toString() + ' (' + err.code + ')');
						process.exit(1);
					}

					client.end();
					cb();
				}
			);
		}
	});

}



function create_objects()
{
	var client = null;
	if (commander.dburi)
	{
		print_info("Connecting to database...");
		client = new pg.Client(commander.dburi);

		client.connect(function(err) {

			if (err)
			{
				console.log();
				print_err("Error connecting to " + commander.dburi + ": " + err.toString() + ' (' + err.code + ')');
				if (err.code == '3D000') // database "pinotage" does not exist
				{
					console.log();
					print_warn('Please ensure your database settings are correct. You can create a database in the following ways:');
					level++;
					print_warn("* Use the createdb command (included in the postgres installation)");
					print_warn("* Connect to the database and issue a 'CREATE DATABASE ' command");
					print_warn("* Provide the -c, --create option to this program");
					console.log();
				}

				process.exit(1);
				return;
			}
			else
			{
				print_ok("Connected");
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
				level++;
				print_warn(err);
				level--;
			}
			else
			{
				level++;
				print_err(err);
				level--;

				client.end();
				process.exit(1);
				return;
			}
		}
		if (sql_list.length <= 0)
		{
			print_info("DONE");

			if (client)
				client.end();

			process.exit(0);
			return;
		}

		var nextfile = sql_list.shift();
		print_info("Creating " + nextfile.filename + " (" + nextfile.data.length + " bytes)");

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

print_info("Building list...");

commander.args.forEach(function (f) {
	load_entry(f);
});

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

