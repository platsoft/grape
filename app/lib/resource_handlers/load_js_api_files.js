
const fs = require('fs');
const util = require('util');

module.exports = function(app, dirname) {
	
	/**
	 * Recursively loads js files into the application space
	 *
	 * @param {string} relativedirname - Used by loadapifiles() to recursivly loop through the api directories
	 */
	function loadapifiles(dirname, relativedirname)
	{
		//make sure last character is a /
		if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

		if (dirname[dirname.length - 1] != '/') dirname += '/';

		var files = fs.readdirSync(dirname);
		for (var i = 0; i < files.length; i++)
		{
			var file = files[i];
			var fstat = fs.statSync(dirname + file);
			if (fstat.isFile())
			{
				var ar = file.split('.');
				if (ar[ar.length - 1] == 'js')
				{
					// loads the api module and execute the export function with the app param.
					try {
						require(dirname + file)(app);
						app.get('logger').info('api', "Loaded API file " + relativedirname + file);
					} catch (e) {
						app.get('logger').error('api', "Failed to load API file " + relativedirname + file + ' [' + util.inspect(e) + ']');
					}
				}
			}
			else if (fstat.isDirectory())
			{
				loadapifiles(dirname + '/' + file, relativedirname + file);
			}
		}
	}

	loadapifiles(dirname, '');
};

