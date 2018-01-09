
const _ = require('underscore');
const fs = require('fs');
const path = require('path');


//merge fields in the two objects
//	arrays are joined
function merge_objects(o1, o2)
{
	var ret = o1;
	var keys2 = Object.keys(o2);

	keys2.forEach(function (key) {
		if (_.isArray(o2[key]))
		{
			if (!ret[key])
				ret[key] = o2[key];
			else if (_.isArray(ret[key]))
				ret[key] = _.union(o2[key], ret[key]);
			else
				ret[key] = _.union(o2[key], [ret[key]]);
		}
		else //override it
		{
			ret[key] = o2[key];
		}
	});

	return ret;
}


function read_file(configfile)
{
	var config = null;

	if (path.extname(configfile) == '.json')
	{
		try {
			config = JSON.parse(fs.readFileSync(configfile, 'utf8'));
		} catch (e) {
			if (e.code == 'ENOENT')
			{
				throw 'File not found: ' + configfile;
			}
			else
			{
				console.log(e);
				throw 'Could not read JSON file: ' + configfile;
			}
		}
	}
	else
	{
		try {
			config = require(configfile);
		} catch (e) {
			if (e.code == 'MODULE_NOT_FOUND')
			{
				throw 'File not found: ' + configfile;
			}
			else
			{
				console.log(e);
				throw 'Could not load module: ' + configfile;
			}
		}
	}

	return config;
}

// process a new config file (string containing path to js or json file), or object with options
function process_options(_o)
{
	console.log("Processing ", _o);
	var base_directory = null;
	var options;

	if (_.isString(_o) && 
		(path.extname(_o) == '.js' || path.extname(_o) == '.json'))
	{
		if (!path.isAbsolute(_o))
		{
			_o = path.join(process.cwd(), _o);
		}
		
		options = read_file(_o);

		base_directory = path.dirname(_o);
	}
	else
	{
		options = _o;

		base_directory = options.base_directory || null;
	}

	if (options.include && _.isArray(options.include))
	{
		options.include.forEach(function(file) {
			var included_options = process_options(path.join(base_directory, file));
			options = merge_objects(included_options, options); //the previously set options must get priority
		});
		delete options.include;
	}

	// backwards compatibility: get rid of the public_directory
	if (options.public_directory)
	{
		if (_.isArray(options.public_directory))
		{
			options.public_directories = options.public_directory;
		}
		else if (_.isArray(options.public_directories))
		{
			options.public_directories.push(options.public_directory);
		}
		else
		{
			options.public_directories = [options.public_directory];
		}

		delete options.public_directory;
	}

	// change paths in public_directories to absolute paths
	if (options.public_directories)
	{
		var new_pds = [];
		options.public_directories.forEach(function(pd) {
			if (path.isAbsolute(pd))
				new_pds.push(pd);
			else
				new_pds.push(path.join(base_directory, pd));
		});
		options.public_directories = new_pds;
	}

	// change paths in api_directories to absolute paths
	if (options.api_directories)
	{
		var new_dirs = [];
		options.api_directories.forEach(function(dir) {
			if (path.isAbsolute(dir))
				new_dirs.push(dir);
			else
				new_dirs.push(path.join(base_directory, dir));
		});
		options.api_directories = new_dirs;
	}


	return options;
}

exports = module.exports = function() {
	var options = {
		session_management: false,
		api_directory: false,
		api_ignore: [], //files to ignore when loading api files
		port: 3000,
		http_port: false,
		public_directory: false,
		debug: false,
		instances: 1,
		document_store: false,
		base_directory: false,
		log_directory: false,
		server_timeout: 50000,
		compile_js_dirs: ['pages'],
		public_directories: [],
		api_directories: [],
		cache_public_js_dirs: false,
		process_name: false,
		enable_notifications: false,
		delayed_response: 0
	};

	for (var i = 0; i < arguments.length; i++)
	{
		options = merge_objects(options, process_options(arguments[i]));
	}

	if (!options.base_directory)
	{
		options.base_directory = path.dirname(process.mainModule.filename);
	}

	if (options.log_directory == false && options.base_directory != false)
	{
		if (!fs.existsSync(options.base_directory + '/log/'))
			fs.mkdirSync(options.base_directory + '/log/');
		options.log_directory = fs.realpathSync(options.base_directory + '/log/');
	}

	if (options.document_store == false && options.base_directory != false)
	{
		if (!fs.existsSync(path.join(options.base_directory, '/repo/')))
			fs.mkdirSync(options.base_directory + '/repo/');
		options.document_store = fs.realpathSync(options.base_directory + '/repo/');
	}

	return options;
};


