
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
		log_directory: false
	};

	_.extend(options, _o);
	
	if (options.base_directory == false && options.public_directory != false)
	{
		options.base_directory = fs.realpathSync(options.public_directory + '/../');
	}
	if (options.log_directory == false && options.base_directory != false)
	{
		if (!fs.existsSync(options.base_directory + '/log/'))
			fs.mkdirSync(options.base_directory + '/log/');
		options.log_directory = fs.realpathSync(options.base_directory + '/log/');
	}

	return options;
};



