
var _ = require('underscore');
var fs = require('fs');
var path = require('path');

exports = module.exports = function(_o) {
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
		process_name: false
	};


	if (!_o.base_directory && _o.public_directory)
	{
		_o.base_directory = fs.realpathSync(_o.public_directory + '/../');
	}

	// TODO use path.isAbsolute on directory options, if it is not absolute add base directory to them

	if (_o.base_directory)
	{
		try {
			var stat = fs.statSync(_o.base_directory + '/default_config.js');
			if (stat.isFile())
			{
				try {
					var defaults = require(_o.base_directory + '/default_config.js'); 
					_.extend(options, defaults);
				} catch (e) {
					console.log("Error while reading " + _o.base_directory + '/default_config.js');
					console.log(e);
				}
			}
		} catch (e) { 
		}
	}
	
	_.extend(options, _o);

	if (_.isArray(options.public_directory) && options.public_directories.length == 0)
	{
		options.public_directories = options.public_directory;
		options.public_directory = options.public_directories[0];
	}


	if (options.log_directory == false && options.base_directory != false)
	{
		if (!fs.existsSync(options.base_directory + '/log/'))
			fs.mkdirSync(options.base_directory + '/log/');
		options.log_directory = fs.realpathSync(options.base_directory + '/log/');
	}

	if (options.document_store == false)
	{
		if (options.base_directory != false)
		{
			if (!fs.existsSync(options.base_directory + '/repo/'))
				fs.mkdirSync(options.base_directory + '/repo/');
			options.document_store = fs.realpathSync(options.base_directory + '/repo/');
		}
	}

	if (options.public_directory 
			&& typeof options.public_directory == 'string' 
			&& options.public_directories.indexOf(options.public_directory) < 0)
		options.public_directories.push(options.public_directory);

	options.public_directories = _.uniq(options.public_directories, false);

	if (options.api_directory)
		options.api_directories.push(options.api_directory);
	
	options.api_directories = _.uniq(options.api_directories, false);

	return options;
};



