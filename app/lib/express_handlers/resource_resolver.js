
// Look at the request and try to figure out how to handle it. At the moment there are two ways: API calls and HTML files
// This express handler will fill in req.handler with the following fields: 
// 	handler_type: 'api' or 'staticfile'
//	matched_path: path
//

var path = require('path');
var fs = require('fs');

module.exports = function() {


	function send_404(req, res)
	{
		if (req.accepts_json)
			res.status(404).send({status: 'ERROR', code: -2, message: 'The path you requested (' + req.path + ') could not be found'}).end();
		else
			// TODO serve 404 error file?
			res.status(404).send('The path you requested (' + req.path + ') could not be found').end();

	}

	return function(req, res, next) {
		var app = req.app;

		req.handler = null;

		var resource_handlers = app.get('resource_handlers');
		for (var i = 0; i < resource_handlers.length; i++)
		{
			var rh = resource_handlers[i];
			var handler = rh.identify(req, res);
			if (handler)
			{
				req.handler = handler;
				req.resource_handler = rh;
				next();
				return;
			}
		}

		app.get('logger').log('app', 'error', 'Resource not found: ', pathname);
		
		send_404(req, res);
	};
};



