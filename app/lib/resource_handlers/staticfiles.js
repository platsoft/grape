
const path = require('path');
const fs = require('fs');

function StaticFileHandler()
{
	var self = this;
	this.self = self;

	function check_permissions (req, res, next)
	{
		//console.log("CHECK PERMISSIONS");
		next();
	}

	function execute (req, res, next)
	{
		var app = req.app;
		//console.log("EXECUTE");
		app.get('logger').log('session', 'info', 'Sending public file ' + req.handler.matched_path);
		res.sendFile(req.handler.matched_path, {}, function(err) {
			if (err)
			{
				app.get('logger').log('app', 'error', 'Error sending file: ' + err.toString());
			}
		});
	}

	this.identify = function(req, res) {
		var app = req.app;

		if (req.method != 'GET')
		{
			app.get('logger').error('app', req.method + ' request could not be matched to any API handler');
			return null;
		}

		var pathname = decodeURI(req.path);
		var lookup_result = null;

		// special GET request / will change the request to /index.html
		if (pathname == '/')
		{
			pathname = '/index.html';
		}

		var public_directories = app.get('config').public_directories;
		for (var i = 0; i < public_directories.length; i++)
		{
			try {
				var fullpath = path.join(public_directories[i], pathname);
				var stat = fs.statSync(fullpath);
				if (stat.isFile())
				{
					lookup_result = path.normalize(fullpath);
					
					// TODO make sure that lookup_result is inside public_directories[i]

					// TODO E-Tag info can come from here
					var handler = {
						handler_type: 'staticfile',
						matched_path: lookup_result,
						public_directory: public_directories[i],
						check_permissions: check_permissions,
						execute: execute
					};
					app.get('logger').log('app', 'debug', 'Matched public file ' + lookup_result);
					
					return handler;
				}
			} catch (e) {
			}
		}

		return null;
	};

	this.init = function() {
	};
}

module.exports = StaticFileHandler;

