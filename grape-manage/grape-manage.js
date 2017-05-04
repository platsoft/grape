#!/usr/bin/env node

// Reads __dirname + cmd/ for commands

var fs = require('fs');
var util = require('util');
var path = require('path');
var grape_options = require(__dirname + '/../app/lib/options.js');
var pg = require('pg');
var funcs = require('./funcs');

var base_directory = process.cwd();
var modules = [];
var running_module = null;
var dbconn = null;
var builtin_commands = {};


// Extract possible --project-dir=DIRNAME. I guess we should use commander here
if (process.argv[2] && process.argv[2].substring(0, 13) == '--project-dir')
{
	var c = null;
	if (process.argv[2][13] == '=')
	{
		c = '=';
		var ar = process.argv[2].split(c);
		base_directory = path.resolve(ar[1]);
		process.argv.splice(2, 1);
	}
	else if (process.argv[2].length == 13)
	{
		base_directory = path.resolve(process.argv[3]);
		process.argv.splice(2, 2);
	}
	else
	{
		print_help();
		process.exit(1);
	}

}




try {
	var config = require(base_directory + '/config.js');
} catch (e) {
	console.log("No config.js file found! Make sure that you are in a project directory. Alternatively, use the --project-dir option");
	process.exit(1);
}

var options = grape_options(config);


function debug(msg)
{
	//console.log(msg);
}

builtin_commands['list'] = function() {
	modules.forEach(function(module) {
		console.log(module.info.name);
	});
	Object.keys(builtin_commands).forEach(function(name) {
		console.log(name);
	});
};

function process_directory(dirname, cb)
{
	fs.readdir(dirname, function(err, files) {
		if (err)
		{
			debug("Error while processing " + dirname + ".", err);
			cb(err);
			return;
		}

		files.forEach(function(file) {
			if (path.extname(file) == '.js')
			{
				var jsfile_path;
				try {
					jsfile_path = path.normalize([dirname, file].join('/'));
					debug("Reading " + jsfile_path);

					var cmd_module = require(jsfile_path);
					if (cmd_module.info && cmd_module.run)
					{
						cmd_module.info.name = path.basename(jsfile_path, '.js');
						modules.push(cmd_module);
						debug("Loaded " + jsfile_path);
					}
					else
					{
						debug("Ignoring " + jsfile_path);
					}
				} catch (e) {
					console.log("Error while loading " + jsfile_path);
					console.log(e.stack);
				}
			}
		});

		cb(null, modules);
	});
}

function print_help()
{
	console.log();
	console.log("\tUsage: grape-manage [command] [options]");
	console.log();
	console.log("\tCommands:");
	console.log();
		
	//console.log("\t\t", "help", "\t\t", "Prints information for a command");
	console.log("\t\t", "list", "\t\t", "Lists all available commands");

	modules.forEach(function(module) {
		console.log("\t\t", module.info.name, "\t", module.info.description);
	});
	console.log();
}

function done(err)
{
	if (err)
		funcs.print_error("Error: " + err);
	if (dbconn)
	{
		dbconn.end();
	}
	process.exit(1);
}

function run()
{

	if (process.argv.length <= 2)
	{
		print_help();
	}
	else
	{
		var found = false;
		var command = process.argv[2];

		//built-in commands
		if (typeof builtin_commands[command] == 'function')
		{
			builtin_commands[command]();
			return;
		}

		modules.forEach(function(module) {
			if (module.info.name == command)
			{
				var argv = process.argv;
				argv.splice(1, 1);

				found = true;
				if (module.info.db === true)
				{
					dbconn = new pg.Client(options.dburi);
					dbconn.connect(function (err) {
						if (err)
						{
							console.log("Connecting to ", options.dburi);
							console.log("Error: could not connect to database");
							return;
						}
						
						module.run({
							db: dbconn, 
							argv: argv, 
							options: options,
							funcs: funcs,
							base_directory: base_directory
						}, done);
					});
				}
				else
				{

					module.run({
						db: null,
						argv: argv,
						options: options,
						funcs: funcs,
						base_directory: base_directory
					}, done);
				}

			}
		});

		if (!found)
		{
			console.log("No such command: " + command);
		}
	}
}


process_directory(__dirname + '/cmd', function(err, modules) {
	process_directory(base_directory + '/cmd', function(err, modules) {
		process_directory(base_directory + '/scripts/cmd', function(err, modules) {
			run();
		});
	});
});

