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
var events = require('events');
var grapelib = require(__dirname + '/../index.js');

const dblib = require(__dirname + '/db.js');
	

//express handlers
const resource_resolver_handler = require(__dirname + '/express_handlers/resource_resolver.js');
const session_handler = require(__dirname + '/express_handlers/session_handler.js');
const check_permission_handler = require(path.join(__dirname, 'express_handlers', 'check_permissions.js'));

//resource handlers
const staticfile_handler = require(path.join(__dirname, 'resource_handlers', 'staticfiles.js'));
const api_handler = require(path.join(__dirname, 'resource_handlers', 'api.js'));

var DEFAULT_MAXSOCKETS = 500;

/**
 * Sets up 2 database connections for app
 */
function init_database(app)
{
	var options = app.get('config');
	if (options.dburi)
	{
		//database connection for guest sessions. This allows us to specify a different DB username for guest sessions
		var guest_db = new dblib({
			dburi: options.guest_dburi || options.dburi,
			debug: options.debug,
			session_id: 'grape-guest-' || process.pid.toString(),
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


var grape_express_app = function(options, grape_obj) {

	var self = this;
	this.self = self;

	this.grape_obj = grape_obj;

	// entry
	var app = express();
	this.app = app;

	this.express = app;

	var logger = grape_obj.logger;
	var cache = grape_obj.comms;

	app.set('config', options);

	app.set('logger', logger);
	app.set('log', logger);
	app.logger = logger;

	app.set('cache', cache);
	app.set('comms', cache);

	// Grape Utils
	app.set('gutil', grapelib.utils);

	// Resource handlers
	var resource_handlers = [
		new api_handler(app), 
		new staticfile_handler(app)
	];

	app.set('resource_handlers', resource_handlers);

	app.set('grape_settings', grape_obj.grape_settings);

	// Express settings
	app.set("jsonp callback", true);
	app.enable("trust proxy");
	app.disable("x-powered-by");
	app.disable("etag");





	// Document Store setup
	var document_store = new grapelib.document_store(options);
	app.set('document_store', document_store);
	app.set('ds', document_store);

	// PDF Generator setup - TODO this should not be here
	var pdfgenerator = new grapelib.pdfgenerator(app);
	app.set('pdfgenerator', pdfgenerator);

	// Database init
	init_database(app);
	
	app.set('db', grape_obj.db);

	// Express Handlers goes here:
	
	// Step 1: Log incoming request
	app.use(function(req, res, next) {
		logger.log('app', 'trace', [req.ip, req.method, req.url, req.header('Content-Length') || 0].join(' '));
		next();
	});

	// Step 2: Parse body
	app.use(bodyParser.json());
	app.use(multipartParser());
	app.use(xmlParser());

	if (options.delayed_response)
	{
		// Simulate a slow network - sleep for a little while
		app.use(function(req, res, next) {
			setTimeout(next, options.delayed_response);
		});
	}

	// Step 3: Resolve resource
	app.use(resource_resolver_handler());

	// Step 4: Confirm session information
	app.use(session_handler());

	// Log the result from the session check
	app.use(function(req, res, next){
		if (req.session_id)
			logger.log('session', 'debug', 'Valid session. User: ', req.session.username);
		else
			logger.log('session', 'debug', 'No valid session - continuing as guest');
		next();
	});

	// Step 5: Check permissions
	app.use(function(req, res, next) {
		req.handler.check_permissions(req, res, next);
	});

	/*
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
	});
	*/


	// Add the results from notification functions into X-Notifications header
	if (options.enable_notifications)
	{
		var notification_checker = require(__dirname + '/notification_checker.js');
		app.use(notification_checker);
	}

	// TODO This is where the api logger handler should be included
	
	// API CALLS

	// call the resource handler
	app.use(function(req, res, next) {
		if (req.handler && req.handler.execute)
		{
			req.handler.execute.call(req.resource_handler, req, res, next);
		}
		else
		{
			// this should not happen
			res.status(500).end();
		}
	});

	for (var i = 0; i < resource_handlers.length; i++)
	{
		resource_handlers[i].init();
	}



	this.start = function ()
	{
		var options = app.get('config');

		var http_port = false;

		if (options.use_https && options.use_https === true)
		{
			var https = require('https');
			https.globalAgent.maxSockets = options.maxsockets || DEFAULT_MAXSOCKETS;

			var privateKey = fs.readFileSync(options.sslkey);
			var certificate = fs.readFileSync(options.sslcert);

			var server = https.createServer({key: privateKey, cert: certificate}, app).listen(options.port);

			server.on('error', function(err) {
				if (err.code == 'EADDRINUSE')
				{
					logger.error('app', 'Port ', options.port, ' is already in use');
					process.exit(9);
				}
			});

			self.https_server = server;

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

			server.on('error', function(err) {
				if (err.code == 'EADDRINUSE')
				{
					logger.error('app', 'Port ', http_port, ' is already in use');
					process.exit(9);
				}
			});
			
			self.http_server = server;

			logger.info('HTTP listening on ' + http_port);
		}
		
		self.emit('listening');
	}

};

grape_express_app.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = grape_express_app;
