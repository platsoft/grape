/**
 * Worker apps. Starts listening on port, loads API files, public files 
 *
 */
var express = require('express');
var bodyParser = require('body-parser');
var cookieParser = require('cookie-parser');
var multipartParser = require('connect-multiparty');
var _ = require('underscore');
var fs = require('fs');
var util = require('util');

exports = module.exports = function(_o) {
	var app = express();
	
	app.use(bodyParser());
	app.use(cookieParser());
	app.use(multipartParser());
	
	var options = require(__dirname + '/options.js')(_o);
	
	var _logger = require(__dirname + '/logger.js');
	var logger = new _logger(options);

	app.set('logger', logger);
	app.set('log', logger);

	app.set('config', options);

	app.set("jsonp callback", true);

	var gutil = require(__dirname + '/util.js');
	app.set('gutil', new gutil());

	var document_store = new (require(__dirname + '/document_store.js'))(options);
	app.set('document_store', document_store);
	
	logger.info('Starting application (pid ' + process.pid + ') with options: ' + util.inspect(options));

	//if database loading is requested
	if (options.dburi)
	{
		var _db = require(__dirname + '/db.js');
		var db = new _db({
			dburi: app.get('config').dburi, 
			debug: app.get('config').debug,
			debug_logger: function(s) { app.get('logger').db(s); },
			error_logger: function(s) { app.get('logger').db(s); }
		});

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

	function loadpublicjsfiles(dirname, relativedirname)
	{
		var data = '';

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
					data += '// JAVASCRIPT FILE ' + dirname + file + "\n";
					data += fs.readFileSync(dirname + file);
					app.get('logger').info("Loaded " + relativedirname + file);
				}
			}
			else if (fstat.isDirectory()) 
			{
				data += loadpublicjsfiles(dirname + '/' + file, relativedirname + file);
			}
		}
		return data;
	}

	function setup_public_directory(dirname)
	{
		app.use(function(req, res, next) 
		{
			var accepts_json = (req.headers.accept && req.headers.accept.indexOf('application/json') != -1);
			
			//GET which does not accept JSON 
			if (req.method == 'GET' && !accepts_json)
			{
				console.log(req._parsedUrl.pathname);
				//TODO this is insecure, make sure that fileName exists in publicPath
				var fileName = app.get('publicPath') + decodeURI(req.path);
				if (fs.existsSync(fileName)) //public file
				{
					console.log("Sending file " + fileName);
					res.sendfile(fileName);
					return;
				} 
				else if (req._parsedUrl.pathname == '/download_public_js_files') //special path to download all javcascript files recursively in /public/pages/
				{
					var jsdata = loadpublicjsfiles(app.get('publicPath') + '/pages', '/');
					res.set('Content-Type', 'application/javascript');
					res.send(jsdata);
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

	
	//first function to be called on a new request
	app.use(function(req, res, next) 
	{
		logger.trace([req.ip, req.method, req.url].join(' '));
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
	logger.info("Loading built-in API calls from " + builtin_api_dir);
	loadapifiles(builtin_api_dir, '');

	if (options.api_directory)
	{
		loadapifiles(options.api_directory, '');
	}
		

	var http = require('http');
	http.globalAgent.maxSockets = 50;

	var server = app.listen(options.port);

	logger.info('Listening on ' + options.port);

	server.timeout = 50000;
	
	return app;
};


