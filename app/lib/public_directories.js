
var path = require('path');
var fs = require('fs');

module.exports = function() {
	function send_404(req, res)
	{
		if (req.accepts_json)
			res.status(404).send({status: 'ERROR', code: -2, message: 'The path you requested (' + req.path + ') could not be found'});
		else
			// TODO serve 404 error file?
			res.status(404).send('The path you requested (' + req.path + ') could not be found');

	}

	return function(req, res, next) {
		var app = req.app;

		// If we matched an API call earlier, do not try to serve any HTML files
		if (req.matched_path && req.matched_path != '')
		{
			app.get('logger').debug('api', 'Matched API call ' + req.matched_path);
			next();
			return;
		}

		if (req.method != 'GET')
		{
			app.get('logger').error('app', 'API could not be matched and request is not GET (it is ' + req.method + ')');
			send_404(req, res);
			return;
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
				var fullpath = path.normalize([public_directories[i], '/', pathname].join(''));
				var stat = fs.statSync(fullpath);
				if (stat.isFile())
				{
					lookup_result = path.normalize(fullpath);
					break;
				}
			} catch (e) {
			}
		}

		if (lookup_result != null)
		{
			res.sendFile(lookup_result);
			return;
		}
	
		app.get('logger').log('app', 'error', 'Path not found: ' + pathname);

		send_404(req, res);
	};
};

