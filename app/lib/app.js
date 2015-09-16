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

var auto_validate = require('./auto_validate.js');

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

	function validate_object(obj, validation_string)
	{
		var ret = auto_validate.validate(obj, validation_string);
		if(ret.errors && ret.errors.length > 0)
		{
			throw new Error('Validation failure: ' + ret.errors[0]);
		}
		else return ret.obj;
	}

	/*
	param : {
		name,
		method,
		url,
		db_function,
		validation_string
	}
	 */
	app.add_api_call = function(param)
	{
		var self = this;
		function call_api_function(req, res) {
			try
			{
				var obj = req.body;
				_.each(_.keys(req.params), function(field) {
					req.body[field] = req.params[field];
				});

				if (param.validation_string)
				{
					obj = validate_object(obj, param.validation_string);
				}

				res.locals.db.json_call(param.db_function, obj, null, {response: res});
			}
			catch (e)
			{
				logger.error(e.stack);
				res.send({
					status: 'ERROR',
					message: e.message,
					code: -99,
					error: e
				});
			}
		}
		// Validation
		if (!param) return;
		if (param.method != 'get' && param.method != 'post')
			throw new Error('Invalid API method provided: ' + param.method);
		if (!param.db_function)
			throw new Error('No db_function provided');
		if (!param.url)
			throw new Error('No url provided');

		logger.info('Registering API call ' + param.name + ' as ' + param.method + ':' + param.url);
		if (param.method == 'get')
		{
			self.get(param.url, call_api_function);
		}
		else if (param.method == 'post')
		{
			self.post(param.url, call_api_function);
		}
	}

	app.create_api_calls = function (param)
	{
		var self = this;
		if (!param) return;
		if (!param.url_prefix)
			param.url_prefix = '';

		if (param.url_prefix.slice(-1) != '/')
			param.url_prefix = param.url_prefix + '/';

		if (!param.db_schema)
			param.db_schema = 'public';

		var key_val = param.param_id;
		if( !key_val )
			key_val = param.name + '_id';

		for (var i = 0; i < param.operations.length; i++)
		{
			entry = param.operations[i];
			op = entry.name;

			if (op == 'view')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'get',
					url               : param.url_prefix + param.name + '/:' + key_val,
					db_function       : param.db_schema + '.view_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else if (op == 'create')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name,
					db_function       : param.db_schema + '.save_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else if (op == 'update')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name + '/:' + key_val,
					db_function       : param.db_schema + '.save_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name + '/:' + key_val + '/' + op,
					db_function       : param.db_schema + '.' + op + '_' + param.name,
					validation_string : entry.validation_string
				});
			}
		}
	};


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

	server.timeout = options.server_timeout;

	return app;
};
