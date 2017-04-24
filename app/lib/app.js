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
var path = require('path');
var schema_api_calls = require(__dirname + '/schema_api_calls.js');

var DEFAULT_MAXSOCKETS = 500;

exports = module.exports = function(_o) {

	// entry
	var app = express();

	var grapelib = require(__dirname + '/../index.js');

	var options = grapelib.options(_o);
	app.set('config', options);

	/**
	 * Sets up database
	 */
	function setup_database(app)
	{
		var options = app.get('config');
		if (options.dburi)
		{
			var _db = require(__dirname + '/db.js');
			var db = new _db({
				dburi: options.dburi,
				debug: options.debug,
				session_id: 'default'
			});

			db.on('error', function(err) {
				app.get('logger').log('db', 'error', err);
			});

			db.on('debug', function(msg) {
				app.get('logger').log('db', 'debug', msg);
			});

			db.on('end', function() {
				app.get('logger').log('db', 'info', 'Database disconnected. Restarting');
				db.connect();
			});


			
			app.set('db', db);

			/*
			var StaticData = require(__dirname + '/static_data.js');
			var SD = new StaticData({db: db});
			app.set('SD', SD);
			*/

			//database connection for guest sessions. This might allow us to, in future, to specify a different DB username for guest sessions
			var guest_db = new _db({
				dburi: options.guest_dburi || options.dburi,
				debug: options.debug,
				session_id: 'guest',
				debug_logger: function(s) { app.get('logger').db(s); }
			});

			guest_db.on('error', function(err) {
				app.get('logger').log('db', 'error', err);
			});
			
			guest_db.on('debug', function(msg) {
				app.get('logger').log('db', 'debug', msg);

			});

			guest_db.on('end', function() {
				app.get('logger').log('db', 'info', 'Guest db conn disconnected. Restarting');
				guest_db.connect();
			});


			app.set('guest_db', guest_db);
		}
	}

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

		if (options.api_ignore.indexOf(relativedirname) != -1)
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
				if (ar[ar.length - 1] == 'js' && options.api_ignore.indexOf(file) === -1)
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


	function setup_public_directory(app)
	{

		// Tries to serve a file in one of the app's public directories
		app.use(function(req, res, next)
		{
			// Matched an API call
			if (req.matched_path && req.matched_path != '')
			{
				app.get('logger').debug('api', 'Matched API call ' + req.matched_path);
				next();
				return;
			}

			var pathname = decodeURI(req.path);
			var lookup_result = null;

			// special GET request / will change the request to /index.html
			if (pathname == '/')
			{
				pathname = '/index.html';
			}

			// check if the path exists in one of our public directories
			// only do this check if the request is a GET
			// if it accepts JSON, and the path ends with .json, also look for the file
			if (req.method == 'GET' && (!req.accepts_json || path.extname(pathname) == 'json'))
			{
				var public_directories = app.get('config').public_directories;
				for (var i = 0; i < public_directories.length; i++)
				{
					// TODO cache this
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
			}

			if (lookup_result != null)
			{
				res.sendFile(lookup_result);
				return;
			}

			// we didn't serve any files from the public directory - if this request accepts json it is most probably an API call
			if (req.accepts_json)
			{
				next();
				return;
			}

			// if the path begins with /download, we just allow it to go into the API calls
			// TODO make this configurable. the API calls should specifically add themselves to a special list if they produce something other than JSON
			//if (pathname.slice(0, 9) == '/download')
			//{
			//	next();
			//	return;
			//}

			if (pathname.indexOf('.') >= 0)
			{
				// TODO serve 404 error file?
				res.status(404).send('The path you requested (' + pathname + ') on a non-JSON accepting request could not be found');
			}
			else
			{
				console.log("Deprecated use of Grape auto send index.html feature!");
				app.get('log').trace("Deprecated use of Grape auto send index.html feature!");
				res.sendfile(public_directories[0] + '/index.html');
			}
		});
	}

	//Setup functions for auto create of API calls
	var create_api_calls = require(__dirname + '/create_api_calls.js');
	create_api_calls(app);


	// The first handler to be called on a new request
	// This handler appends session information to the request for further processing
	// It will add the following variables to req:
	//	session_id
	//	accepts_json (true or false)
	//	db
	app.use(function(req, res, next)
	{
		req.session_id = null;

		if (req.header('X-SessionID'))
			req.session_id = req.header('X-SessionID');

		if (req.headers.accept)
			var accept = req.headers.accept.substring(0, req.headers.accept.indexOf(';'));
		else
			accept = null;

		logger.log('app', 'trace', [req.ip, req.method, req.url, req.session_id, req.header('Content-Length'), accept].join(' '));

		// if first character of path is a . return error
		if (req.path[0] == '.')
		{
			res.status(403);
			res.set('X-Permission-Error', 'Permission denied');
			if (req.headers.accept.indexOf('application/json') != -1)
				res.json({status: 'ERROR', message: 'Permission denied', code: -1});
			else
				res.send('Permission denied');
			return;
		}

		// true if this request accepts json as return
		req.accepts_json = (req.headers.accept && req.headers.accept.indexOf('application/json') != -1);

		res.locals.db = app.get('db');
		req.db = app.get('db');

		// Assign the API call URL to req.matched_path  (if it can be matched)
		var path = req.url;

		req.matched_path = null;

		for (var i = 0; i < app._router.stack.length; i++)
		{
			if (!app._router.stack[i].route) 
				continue;

			var stack = app._router.stack[i];
			var route = stack.route;
			if (stack.match(req.path))
			{
				req.matched_path = route.path;
				break;
			}
		}

		next();
	});

	// Logger setup
	var logger = new grapelib.logger(options);
	app.set('logger', logger);
	app.set('log', logger);

	// Express settings
	app.use(bodyParser.json());
	app.use(cookieParser());
	app.use(multipartParser());

	app.set("jsonp callback", true);
	app.enable("trust proxy");

	app.disable("x-powered-by");

	// Grape Utils
	app.set('gutil', grapelib.utils);

	// Database setup
	setup_database(app);

	// Document Store setup
	var document_store = new grapelib.document_store(options);
	app.set('document_store', document_store);
	app.set('ds', document_store);

	// PDF Generator setup
	var pdfgenerator = new grapelib.pdfgenerator(app);
	app.set('pdfgenerator', pdfgenerator);

	// Public directories
	if (options.public_directory)
		app.set('publicPath', options.public_directory);

	if (options.public_directories)
	{
		app.set('public_directories', options.public_directories);
		setup_public_directory(app);
	}

	// Session Management
	if (options.session_management)
	{
		var session_management = require(__dirname + '/session.js');
		session_management(app);
	}


	// Load built-in API calls
	var builtin_api_dir = __dirname + '/../api/';
	logger.info('api', "Loading built-in API calls from " + builtin_api_dir);
	loadapifiles(builtin_api_dir, '');

	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			loadapifiles(dir, '');
		});
	}
	
	// Load APIs from schemas
	logger.info('api', "Loading built-in API schemas from " + builtin_api_dir);
	schema_api_calls.load_schemas(app, builtin_api_dir, '');
	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			schema_api_calls.load_schemas(app, dir, '');
		});
	}


	function start()
	{
		var options = app.get('config');
		logger.info('app', 'Starting application (pid ' + process.pid + ')');
		logger.debug('app', 'Starting with options: ' + util.inspect(options));

		var http_port = false;

		if (options.use_https && options.use_https === true)
		{
			var https = require('https');
			https.globalAgent.maxSockets = options.maxsockets || DEFAULT_MAXSOCKETS;

			var privateKey = fs.readFileSync(options.sslkey);
			var certificate = fs.readFileSync(options.sslcert);

			var server = https.createServer({key: privateKey, cert: certificate}, app).listen(options.port);

			logger.info('SSL listening on ' + options.port);

			if (options.http_port)
				http_port = options.http_port;
		}
		else
		{
			http_port = options.port;
		}

		if (http_port)
		{
			var http = require('http');
			http.globalAgent.maxSockets = options.maxsockets || DEFAULT_MAXSOCKETS;
			var server = app.listen(http_port);
			server.timeout = options.server_timeout;

			logger.info('HTTP listening on ' + http_port);
		}
	}

	start();
	return app;
};
