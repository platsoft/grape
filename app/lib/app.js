
var express = require('express');
var _ = require('underscore');
var fs = require('fs');
var util = require('util');

exports = module.exports = function(_o) {
	var app = express();
	
	app.use(express.bodyParser());
	app.use(express.cookieParser());
	
	var logger = require(__dirname + '/logger.js');
	app.set('logger', logger);
	
	var options = {
		session_management: false, 
		api_directory: false, 
		apiIgnore: [],
		port: 3000,
		public_directory: false,
		debug: false,
	};

	_.extend(options, _o);
	
	app.set('config', options);

	app.set("jsonp callback", true);

	var gutil = require(__dirname + '/util.js');

	app.set('gutil', new gutil());
	
	logger.info('Starting application with options: ' + util.inspect(options));

	//if database loading is requested
	if (options.dburi)
	{
		var _db = require(__dirname + '/db.js');
		var db = new _db({dburi: options.dburi, debug: options.debug});
		app.set('db', db);
	}


	/**
	 * Loads js files into the application space
	 *
	 * @param {string} relativedirname - Used by loadapifiles() to recursivly loop through the api directories
	 */
	function loadapifiles(dirname, relativedirname) 
	{
		if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

		if (dirname[dirname.length - 1] != '/') dirname += '/';

		//app.get('logger').info('Loading api(s) from: ' + relativedirname);

		if (options.apiIgnore.indexOf(relativedirname) != -1) 
		{
			app.get('logger').info('Ignoring ' + relativedirname + ' - found it in app/apiignore.js');
			return;
		}

		var files = fs.readdirSync(dirname);
		for (var i = 0; i < files.length; i++) 
		{
			var file = files[i];
			var fstat = fs.statSync(dirname + file);
			if (fstat.isFile()) 
			{
				var ar = file.split('.');
				if (ar[ar.length - 1] == 'js' && options.apiIgnore.indexOf(file) === -1) 
				{
					// loads the api module and execute the export function with the app param.
					require(dirname + file)(app);
					app.get('logger').info("Loaded " + relativedirname + file);
				}
			}
			else if (fstat.isDirectory()) 
			{
				loadapifiles(dirname + '/' + file, relativedirname + file);
			}
		}
	}

	function setup_public_directory(dirname)
	{
		app.use(function(req, res, next) 
		{
			var accepts_json = (req.headers.accept && req.headers.accept.indexOf('application/json') != -1);
			
			//GET which does not accept JSON 
			if (req.method == 'GET' && !accepts_json && !req.app._router.matchRequest(req))
			{
				//TODO this is insecure, make sure that fileName exists in publicPath
				var fileName = app.get('publicPath') + decodeURI(req.path);
				if (fs.existsSync(fileName)) //public file
				{
					res.sendfile(fileName);
					return;
				} 
				else if (req.path.slice(0, 9) == '/download') //skip the sending of index.html if path is /download (special case)
				{
				} 
				else 	//send index.html to load app (this is for stuff like /search and /policy/:policy_id)
				{
					res.sendfile(app.get('publicPath') + '/index.html');
					return;
				}
			}
			next();
		});
	}

	app.configure(function() {
		
		//first function to be called on a new request
		app.use(function(req, res, next) 
		{
			logger.trace(req.method + ' ' + req.url);
			res.locals.db = app.get('db');
			req.db = app.get('db');
			next();
		});

		if (options.public_directory)
		{
			app.set('publicPath', options.public_directory);
			setup_public_directory(options.public_directory);
		}

		if (options.session_management)
		{
			var session_management = require(__dirname + '/session.js');
			session_management(app);
		}


		// Load built-in API calls
		var builtin_api_dir = __dirname + '/../api/';
		if (options.debug)
		{
			console.log("Loading built-in API calls from " + builtin_api_dir);
		}
		loadapifiles(builtin_api_dir, '');


		if (options.api_directory)
		{
			loadapifiles(options.api_directory, '');
		}
		

	});

	var http = require('http');
	http.globalAgent.maxSockets = 50;

	var server = app.listen(options.port);

	if (options.debug)
	{
		console.log('Listening on ' + options.port);
	}

	server.timeout = 50000;
	
	return app;
};


