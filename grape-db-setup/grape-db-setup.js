#!/usr/bin/env node

var commander = require('commander');

commander
	.description('Load SQL files into a database or stdout')
	.usage('[options] | [directory directory directory ...] | [file file file ...]')
	.option('-d, --dburi [dburi]', 'DB connection string (postgres://user:password@host/dbname)')
	.option('-s, --superdburi [superdburi]', 'Connection string for database creation')
	.option('-r, --recreate', 'Drop and recreate the database before creating objects')
	.option('-i, --continue', 'Continue processing when an error occurs (by default, processing will stop)')
	.option('-e, --schema [schema]', 'The default schema to use when creating objects (defaults to "public"). If "none" is specified, search_path will not be set')
	.option('-a, --readconfig [config.js]', 'Reads the DBURI from the file provided (loaded as a node module and looking at the dburi export)')
	.parse(process.argv);


var fs = require('fs');
const path = require('path');
var _ = require('underscore');

var util = require('util');

var pc = require(__dirname + '/lib/print_colors.js');

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
	var configfile = process.cwd() + '/' + commander.readconfig;

	if (path.extname(configfile) == '.json')
	{
		try {
			var config = JSON.parse(fs.readFileSync(configfile, 'utf8'));
		} catch (e) {
			if (e.code == 'ENOENT')
			{
				pc.print_err('File not found: ' + configfile);
			}
			else
			{
				console.log(e);
				pc.print_err('Could not JSON file: ' + configfile);
			}
			process.exit(1);
		}
	}
	else
	{
		try {
			var config = require(configfile);
		} catch (e) {
			if (e.code == 'MODULE_NOT_FOUND')
			{
				pc.print_err('File not found: ' + configfile);
			}
			else
			{
				console.log(e);
				pc.print_err('Could not load module: ' + configfile);
			}
			process.exit(1);
		}
	}
	
	if (!config.dburi)
	{
		pc.print_err("The config file you provided (" + configfile + ") does not contain a dburi field");
		process.exit(1);
	}

	commander.dburi = config.dburi;

	if (!commander.superdburi && config.superdburi)
		commander.superdburi = config.superdburi;
}

if (!commander.schema)
	commander.schema = 'public';


var GrapeDBSetup = new (require('./lib/GrapeDBSetup'))(commander);


pc.print_info("Building list...");

for (var i = 0; i < commander.args.length; i++) 
{
	var f = commander.args[i];
	if (GrapeDBSetup.load_entry(f, 'command line') == false)
	{
		sql_list = [];
		break;
	}
}

if (GrapeDBSetup.sql_list.length == 0)
{
	pc.print_warn('No SQL files found');

	process.exit(1);
}

if (commander.recreate)
{
	GrapeDBSetup.drop_database(
			commander.superdburi, 
			commander.dburi, 
		function(err) {
			if (err)
			{
				process.exit(1);
			}

			GrapeDBSetup.create_database(
				commander.superdburi, 
				commander.dburi, 
				GrapeDBSetup.create_objects
			);
	});
}
else
{
	GrapeDBSetup.create_objects();
}

