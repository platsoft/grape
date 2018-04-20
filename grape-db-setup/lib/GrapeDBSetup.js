
const fs = require('fs');
const pg = require('pg');
const parse_connection_string = require('pg-connection-string').parse;
const pc = require(__dirname + '/print_colors.js');
const path = require('path');
const colors = require('colors');

function normalize_pg_string(o)
{
	if (typeof o == 'string')
		return o;
	return JSON.stringify(o);
}

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
			new_data = ["\nSET search_path TO '", self.options.schema, "';\n", data].join('');
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
				if (line.startsWith('@calljson'))
				{
					var args = line.split(/\s/).filter(function(p){ return p != ''; });
					var jsonfilename = args[2];
					if (!path.isAbsolute(jsonfilename))
						jsonfilename = path.resolve(parent_directory, jsonfilename);

					var glob = require('glob');
					glob(jsonfilename, {}, function (er, files) {
						if (er) { pc.print_err(er); }
						else if (files)
						{
							files.forEach(function (filename) {
								if (args[0] == '@calljson')
									check = self.load_json_file(args[1], 'JSON', filename);
								else
									check = self.load_json_file(args[1], 'JSONB', filename);
								if (!check)
									return false;
							});
						}
					});
				}
				else if (line.startsWith('@patch')) // @patch grape:113 notes
				{
					var args = line.split(/\s/).filter(function(p){ return p != ''; });
					var ar = args[1].split(':');
					if (ar.length != 2 || args.length < 2)
					{
						pc.print_err('Invalid syntax for @patch. Format is @patch system:version notes');
					}
					else
					{
						var system = ar[0];
						var version = ar[1];
						var note = args.slice(2).join(' ');
						var log_file = '';

						sql_list.push({
							data: 'SELECT grape.patch_start ($1, $2, $3, $4)',
							filename: filename,
							params: [system, parseInt(version), note, log_file]
						});
					}
				}
				else if (line.startsWith('@endpatch'))
				{

				}
				else
				{
					var mfilename = path.resolve(parent_directory, line);
					if (self.load_entry(mfilename, filename) == false)
					{
						check = false;
						return false;
					}
				}
			}
		});

		return check;
	}

	// func = function name
	// datatype = json or jsonb
	// filename = file name
	this.load_json_file = function(func, datatype, filename) {
		pc.print_info("Loading JSON file " + filename);
		var sql = ['SELECT ', func, '($1::', datatype, ');'].join('');
		var data = fs.readFileSync(filename, 'utf8').trim();

		sql_list.push({
			data: sql,
			filename: filename,
			params: [data]
		});
		return true;
	};

	this.start_patch = function(system, version, note, log_file) {
		var sql = 'SELECT grape.patch_start($1,$2,$3,$4);';
		var log_file = '';
		var params = [system, version, note, log_file];

		sql_list.push({
			data: sql,
			filename: log_file,
			params: params
		});
		return true;
	};

	this.end_patch = function(system, version) {

	};

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
			pc.print_info("\tConnecting to " + normalize_pg_string(superdburi) + " for superuser connection");
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
			pc.print_info("\tConnecting to " + normalize_pg_string(superdburi) + " for superuser connection");
		}
		else
		{
			client = new pg.Client();
			pc.print_warn("\tFalling back to default settings for superuser connection");
		}


		client.connect(function(err) {
			if (err)
			{
				pc.print_err("Error establishing connection" + (superdburi ? ' to ' + normalize_pg_string(superdburi) : '') + ": " + err.toString() + ' (' + err.code + ')');

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



	this.create_objects = function(cb)
	{
		var client = null;
		if (self.options.dburi)
		{
			pc.print_info("Connecting to database...");
			client = new pg.Client(self.options.dburi);

			client.on('notice', function(msg) {
				console.log(colors.grey('DB message: ' + msg));
			});

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

				typeof cb === 'function' && cb(); // calls callback if it is a function
			}
			else
			{

				var nextfile = sql_list.shift();
				pc.print_info("Creating " + nextfile.filename + " (" + nextfile.data.length + " bytes)");

				if (client)
				{
					if (nextfile.params)
						client.query(nextfile.data, nextfile.params, next);
					else
						client.query(nextfile.data, next);
				}
				else
				{
					console.log('/* CONTENTS OF FILE: ' + nextfile.filename + ' */');
					if (nextfile.params)
					{
						var d = nextfile.data;
						for (var i = 0; i < nextfile.params.length; i++)
						{
							d = d.replace('$' + (i+1), pg.Client.prototype.escapeLiteral(nextfile.params[i]));
						}
						console.log(d);
					}
					else
					{
						console.log(nextfile.data);
					}
					console.log();
					next(null, null);
				}
			}
		}


	}

}

module.exports = GrapeDBSetup;
