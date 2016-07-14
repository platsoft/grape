
var _ = require('underscore');
var fs = require('fs');

exports = module.exports = function(_o) {
	var options = {
		session_management: false,
		api_directory: false,
		apiIgnore: [],
		port: 3000,
		public_directory: false,
		debug: false,
		instances: 1,
		document_store: false,
		base_directory: false,
		log_directory: false,
		server_timeout: 50000
	};

	if (!_o.base_directory && _o.public_directory)
	{
		_o.base_directory = fs.realpathSync(_o.public_directory + '/../');
	}


	if (_o.base_directory)
	{
		try {
			var stat = fs.statSync(_o.base_directory + '/default_config.js');
			if (stat.isFile())
			{
				var defaults = require(_o.base_directory + '/default_config.js'); 
				_.extend(options, defaults);
			}
		} catch (e) { 
		}
	}
	
	_.extend(options, _o);

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

	return options;
};



