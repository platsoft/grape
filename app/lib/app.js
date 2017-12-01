/**
 * Worker apps. Starts listening on port, loads API files, public files
 * This module is started as a worker app by grape.js
 *
 */
var express = require('express');
var bodyParser = require('body-parser');
var multipartParser = require('connect-multiparty');
var xmlParser = require(__dirname + '/xml_body_parser.js');
var _ = require('underscore');
var fs = require('fs');
var util = require('util');
var path = require('path');
var schema_api_calls = require(__dirname + '/schema_api_calls.js');
var events = require('events');

var DEFAULT_MAXSOCKETS = 500;

var grape_express_app = function(_o) {

	var self = this;
	this.self = self;

	// entry
	this.app = express();
	var app = this.app;

	this.express = app;

	var grapelib = require(__dirname + '/../index.js');

	var options = grapelib.options(_o);
	app.set('config', options);

	/**
	 * Sets up database
	 */
	function init_database(app)
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

			db.on('notice', function(msg) {
				app.get('logger').log('db', 'debug', 'Notice: ' + msg);
			});


			db.on('end', function() {
				app.get('logger').log('db', 'info', 'Database for default session disconnected. Restarting');
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
			guest_db.on('notice', function(msg) {
				app.get('logger').log('db', 'debug', 'Notice: ' + msg);
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


	// Logger setup
	var logger = new grapelib.logger(options);
	app.set('logger', logger);
	app.set('log', logger);





	app.set("jsonp callback", true);
	app.enable("trust proxy");

	app.disable("x-powered-by");
	app.disable("etag");

	// Grape Utils
	app.set('gutil', grapelib.utils);

	// Database init
	init_database(app);

	// Document Store setup
	var document_store = new grapelib.document_store(options);
	app.set('document_store', document_store);
	app.set('ds', document_store);

	// PDF Generator setup
	var pdfgenerator = new grapelib.pdfgenerator(app);
	app.set('pdfgenerator', pdfgenerator);

	// Express settings
	app.use(bodyParser.json());
	app.use(multipartParser());

	//xml body parser
	app.use(xmlParser());


	//Setup functions for auto create of API calls
	var create_api_calls = require(__dirname + '/create_api_calls.js');
	create_api_calls(app);

	var http_auth = require(__dirname + '/http_auth.js');

	if (options.delayed_response)
	{
		// Sleep for a little while
		app.use(function(req, res, next) {
			setTimeout(next, options.delayed_response);
		});
	}

	// Assign the session ID
	app.use(function(req, res, next) {
		//console.log(req.method +  " " + req.url);
		//console.log(req.headers);
		req.session_id = null;

		if (req.header('X-SessionID'))
		{
			req.session_id = req.header('X-SessionID');
			next();
		}
		else if (req.header('Authorization'))
		{
			http_auth(req, res, next);
		}
		else
		{
			next();
		}
	});

	// This handler appends session information to the request for further processing
	// It will add the following variables to req:
	//	accepts_json (true or false)
	//	db
	app.use(function(req, res, next)
	{
		req.accepts_json = null;
		if (req.headers.accept)
		{
			// true if this request accepts json as return
			req.accepts_json = (req.headers.accept && req.headers.accept.indexOf('application/json') != -1);
		}

		logger.log('app', 'trace', [req.ip, req.method, req.url, req.session_id, req.header('Content-Length'), req.headers.accept].join(' '));

		console.log("res.headersSent: ", res.headersSent);

		// if first character of path is a . return error
		if (req.path[0] == '.')
		{
			res.status(403);
			res.set('X-Permission-Error', 'Permission denied');
			if (req.accepts_json)
				res.json({status: 'ERROR', message: 'Permission denied', code: -1});
			else
				res.send('Permission denied');
			return;
		}

		if (req.headers['origin'])
		{
			res.set('Access-Control-Allow-Origin', req.headers['origin']);
		}


		res.locals.db = app.get('guest_db');
		req.db = app.get('guest_db');

		// Assign the API call URL to req.matched_path  (if it can be matched)

		req.matched_path = null;
		for (var i = 0; i < app._router.stack.length; i++)
		{
			var stack = app._router.stack[i];
			if (!stack.route) 
				continue;

			if (stack.match(req.path))
			{
				req.matched_path = stack.route.path;
				break;
			}
		}

		if (req.method == 'OPTIONS' && req.matched_path == null)
		{
			// Handle pre-flight CORS request
			// https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS
		
			logger.log('app', 'trace', ['Pre-flight CORS request from', req.headers['origin']].join(' '));

			res.status(200);
			res.set('Access-Control-Allow-Origin', req.headers['origin']);
			res.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
			res.set('Access-Control-Allow-Headers', 'X-SessionID, X-Notifications, Content-Type');
			res.set('Access-Control-Max-Age', 86400);

			res.end();
			return;
		}

		console.log("res.headersSent: ", res.headersSent);

		next();
	});


	// Public directories
	if (options.public_directories)
	{
		app.set('public_directories', options.public_directories);
		var pd = require(__dirname + '/public_directories.js')();
		app.use(pd);
	}

	// Session Management
	if (options.session_management)
	{
		var session_check_route = require(__dirname + '/session_check_route.js');
		app.use(session_check_route);
	}

	// Assign a database connection for the request
	var assign_db = require(__dirname + '/assign_database.js');
	app.use(assign_db);

	if (options.enable_notifications)
	{
		var notification_checker = require(__dirname + '/notification_checker.js');
		app.use(notification_checker);
	}
	
	// TODO This is where the api logger handler should be included

	// Load built-in API calls
	var builtin_api_dir = __dirname + '/../api/';
	logger.info('api', "Loading built-in API calls from " + builtin_api_dir);
	loadapifiles(builtin_api_dir, '');

	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			if (path.isAbsolute(dir) === true)
				loadapifiles(dir, '');
			else
				loadapifiles(path.join(options.base_directory, dir), '');
		});
	}
	
	// Load APIs from schemas
	logger.info('api', "Loading built-in API schemas from " + builtin_api_dir);
	schema_api_calls.load_schemas(app, builtin_api_dir, '');
	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			if (path.isAbsolute(dir) === true)
				schema_api_calls.load_schemas(app, dir, '');
			else
				schema_api_calls.load_schemas(app, path.join(options.base_directory, dir), '');
				
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
};

grape_express_app.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = grape_express_app;

