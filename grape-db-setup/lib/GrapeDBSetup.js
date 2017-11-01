
var fs = require('fs');
var pg = require('pg');
var parse_connection_string = require('pg-connection-string').parse;
var pc = require(__dirname + '/print_colors.js');
var path = require('path');

function GrapeDBSetup(options)
{
	var self = this;
	var sql_list = [];
	var sql_file_list = [];

	this.options = options;

	this.sql_list = sql_list;
	this.sql_file_list = sql_file_list;

	this.load_entry = function (f, source) 
	{
		pc.level++;
		try {
			var realpath = fs.realpathSync(f);
			var fstat = fs.statSync(realpath);
		} catch (e) {
			pc.print_err('No such file: ' + f + ' (defined in ' + source + ')');
			pc.level--;
			if (!(self.options['continue']))
				return false;
		}

		if (fstat.isDirectory())
		{
			if (self.load_directory(realpath) == false)
				return false;
		}
		else if (fstat.isFile())
		{
			var extname = path.extname(realpath);
			if (extname == '.sql')
			{
				if (self.load_sqlfile(realpath) == false)
					return false;
			}
			else if (extname == '.manifest')
			{
				if (self.load_manifestfile(realpath) == false)
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


	this.load_directory = function(dirname)
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
				if (self.load_entry(filename, dirname) == false)
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
				self.load_directory(current_dir);
				current_dir = dir_list.shift();
			}
		}

		return true;
	}

	this.load_sqlfile = function(filename)
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
			if (self.load_entry(include_filepath, filename) == false)
				return false;

			pc.level--;
		}

		var new_data;
		if (self.options.schema != 'none')
		{
			new_data = ["SET search_path TO '", self.options.schema, "';\n", data].join('');
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
			if (self.load_entry(include_filepath, filename) == false)
				return false;
			pc.level--;
		}

	}

	this.load_manifestfile = function(filename)
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
				if (self.load_entry(mfilename, filename) == false)
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
	this.create_database = function(superdburi, dburi, cb)
	{
		superdburi = superdburi || self.options.superdburi;
		dburi = dburi || self.options.dburi;

		pc.print_info("Creating database...");
		var client = null;
		if (superdburi)
		{
			client = new pg.Client(superdburi);
			pc.print_info("\tConnecting to " + superdburi + " for superuser connection");
		}
		else
		{
			client = new pg.Client();
			pc.print_warn("\tFalling back to default settings for superuser connection");
		}

		client.connect(function(err) {
			if (err)
			{
				pc.print_err("Error establishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');

				if (superdburi == 'postgres')
				{
					process.exit(1);
				}
				else
				{
					pc.print_warn("\tRetrying with database postgres");
					self.create_database('postgres', dburi, cb);
					return;
				}
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

				if (!obj.user)
					obj.user = process.env.USER;
		
				if (!obj.database || !obj.user)
				{
					pc.print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
					process.exit(1);
				}
		
				pc.print_info("\tTarget database name: " + obj.database);
				pc.print_info("\tTarget database user: " + obj.user);

				client.query(['CREATE DATABASE "', obj.database, '" OWNER "', obj.user, '"'].join(''), 
					function(err, res) {
						if (err)
						{
							pc.print_err("Error during database creation: " + err.toString() + ' (' + err.code + ')');

							if (err.code == '42P04')
							{
								pc.print_err("You can use the -r option to drop the database before creation");
							}
							process.exit(1);
						}

						client.end();
						pc.print_ok("\tDatabase created");
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
	this.drop_database = function(superdburi, dburi, cb)
	{
		superdburi = superdburi || self.options.superdburi;
		dburi = dburi || self.options.dburi;
		pc.print_info("Dropping database...");
		var client = null;
		if (superdburi)
		{
			client = new pg.Client(superdburi);
			pc.print_info("\tConnecting to " + superdburi + " for superuser connection");
		}
		else
		{
			client = new pg.Client();
			pc.print_warn("\tFalling back to default settings for superuser connection");
		}


		client.connect(function(err) {
			if (err)
			{
				pc.print_err("Error establishing connection" + (superdburi ? ' to ' + superdburi : '') + ": " + err.toString() + ' (' + err.code + ')');
				
				if (superdburi == 'postgres')
				{
					cb(err);
				}
				else
				{
					pc.print_warn("\tRetrying with database postgres");
					self.drop_database('postgres', dburi, cb);
				}
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

				if (!obj.user)
					obj.user = process.env.USER;

				if (!obj.database || !obj.user)
				{
					pc.print_err('The database options you provided through the --dburi, -d option should specify a database name and user (which will be the owner of the new database), in the format pg://username:password@hostname/databasename');
					process.exit(1);
				}

				pc.print_info("\tTarget database name: " + obj.database);
				pc.print_info("\tTarget database user: " + obj.user);

				// Make sure it is not the same database
				client.query('SELECT current_database()', [], function(err, result) {

					if (err)
					{
						pc.print_err('Error while retrieving the name of the superuser connection!');
						process.exit(1);
					}

					if (result.rows[0].current_database == obj.database)
					{
						pc.print_err('You cannot use the same database for the superuser connection and the target database!');
						pc.print_err('Hint: You can specify another connection string for the superuser connection using the -s option (pg://localhost/postgres)');
						process.exit(1);
					}

			
					client.query('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=$1', [obj.database], function(err, result) {

						client.query(['DROP DATABASE "', obj.database, '"'].join(''), 
							function(err, res) {
								client.end();
								if (err)
								{
									if (err.code != '3D000')
									{
										pc.print_err("Error during database drop: " + err.toString() + ' (' + err.code + ')');
										process.exit(1);
									}
									else
									{
										pc.print_warn("\tFailed to drop database - it does not exist");
									}
								}
								else
								{
									pc.print_ok("\tDatabase dropped");
								}
								cb();
							}
						);
					});
				});
			}
		});

	}



	this.create_objects = function()
	{
		var client = null;
		if (self.options.dburi)
		{
			pc.print_info("Connecting to database...");
			client = new pg.Client(self.options.dburi);

			client.connect(function(err) {

				if (err)
				{
					console.log();
					pc.print_err("Error connecting to " + self.options.dburi + ": " + err.toString() + ' (' + err.code + ')');
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
					pc.print_ok("\tConnected");
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

				if (self.options['continue'])
				{
					pc.level++;
					pc.print_warn(err);
					pc.level--;
				}
				else
				{
					pc.level++;
					pc.print_err(err);
					if (err.internalQuery)
						pc.print_err('Internal Query: ' + err.internalQuery);
					pc.level--;

					client.end();
					process.exit(1);
					return;
				}
			}
			if (sql_list.length <= 0)
			{
				pc.print_ok("DONE");

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

}

module.exports = GrapeDBSetup;

