
const path = require('path');
const fs = require('fs');
const _ = require('underscore');

//api creators
const schema_api_calls = require(path.join(__dirname, 'schema_api_calls.js'));
const js_api_calls = require(path.join(__dirname, 'load_js_api_files.js'));
const auto_create_api_calls = require(path.join(__dirname, 'create_api_calls.js'));

// express handler
const assign_db_handler = require(path.join(__dirname, '..', 'express_handlers', 'assign_database.js'));


function load_api_calls(app)
{
	var logger = app.get('logger');
	var options = app.get('config');
	var list = [];
	var builtin_api_dir = path.join(__dirname, '..', '..', 'api');

	// Load APIs from schemas
	logger.info('api', "Loading built-in API schemas from " + builtin_api_dir);
	list = schema_api_calls.load_schemas(app, builtin_api_dir, '');
	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			var ar = [];
			if (path.isAbsolute(dir) === true)
				ar = schema_api_calls.load_schemas(app, dir, '');
			else
				ar = schema_api_calls.load_schemas(app, path.join(options.base_directory, dir), '');

			list = list.concat(ar);
		});
	}


	//Setup functions for auto create of API calls
	auto_create_api_calls(app);

	// Load JS-style API calls
	logger.info('api', "Loading built-in API calls from " + builtin_api_dir);
	js_api_calls(app, builtin_api_dir);
	if (options.api_directories)
	{
		options.api_directories.forEach(function(dir) {
			if (path.isAbsolute(dir) === true)
				js_api_calls(app, dir);
			else
				js_api_calls(path.join(options.base_directory, dir));
		});
	}

	return list;
}

function APIHandler(app)
{
	var self = this;
	this.self = self;

	this.app = app;

	this.api_list = {};
	
	function permission_denied (req, res, err)
	{

		req.app.get('logger').session('error', 'Permission denied', err.message);

		res.set('X-Permission-Error', err.message);
		res.set('X-Permission-Code', err.code);

		var settings = self.app.get('grape_settings');
		if (req.session_id) // session is fine but permission was denied
		{
			res.status(403).json({status: 'ERROR', message: 'You do not have the necessary access roles to perform this action', code: -2}).end();
		}
		else
		{
			var referer = req.header('referer');
			var login_url = referer + settings.get_value('login_url', '#/grape-ui/login');

			if (referer)
			{
				var param = 'redirect_url=' + encodeURIComponent(referer);

				if (login_url.indexOf('?') < 0)
					login_url += '?' + param;
				else
					login_url += '&' + param;
			}

			res.status(302); // unauthorized

			if (req.accepts('json') == 'json')
			{
				res.send({status: 'ERROR', message: err.message, code: err.code});
			}
			else if (req.accepts('html') == 'html')
			{
				res.set('Location', login_url);
				res.send('Redirecting to <a href="' + login_url + '">Login</a> page...');
			}


		}


		res.end();
	}

	function check_permissions (req, res, next)
	{
		var settings = req.app.get('grape_settings');

		var user_roles = ['guest'];
		if (res.locals.session && res.locals.session.user_roles)
			user_roles = res.locals.session.user_roles;

		var path = req.handler.matched_path;

		var default_access_allowed = settings.get_value('auth.default_access_allowed', 'false');

		var api_def = self.api_list[path];

		if (!api_def)
		{
			// This ugly hack is necessary for backwards compatibility with JS calls
			api_def = self.api_list[path.replace(/:[a-z_]+/g, '.*')];
		}

		if (api_def)
		{
			if (api_def[req.method])
			{
				var allowed_roles = api_def[req.method];
				self.app.logger.debug('api', 'Checking user roles', user_roles, 'against allowed roles', allowed_roles);

				if (_.intersection(allowed_roles, user_roles).length > 0)
				{
					next();
				}
				else
				{
					var msg = [
						'Permission denied for user ', res.locals.session.username || 'guest', 
						' trying to access ', req.method, ':', path, 
						'. User has the following roles: ', user_roles.join(','), 
						' and allowed roles are: ', allowed_roles.join(',')
					].join('');

					permission_denied(req, res, {message: msg, code: 2});
				}
			}
			else
			{
				self.app.logger.error('api', 'Unable to find ACL info for method', req.method, 'of API call', path);

				if (default_access_allowed == 'false')
					permission_denied(req, res, {message: 'Method for path not found and default_access_allowed is false', code: 9});
				else
					next();
			}
		}
		else
		{
			self.app.logger.error('api', 'Unable to find ACL info for API call', path);
			if (default_access_allowed == 'false')
				permission_denied(req, res, {message: 'Path not found and default_access_allowed is false', code: 9});
			else
				next();

		}
	}

	function execute (req, res, next)
	{
		//console.log("EXECUTE");
		
		if (!res.locals.session.username)
			req.app.get('logger').info('session', 'Executing API call', req.handler.matched_path, 'for non-authenticated user');
		else
			req.app.get('logger').info('session', 'Executing API call', req.handler.matched_path, 'for user', res.locals.session.username);

		// Assign a database connection for the request before jumping into the call
		assign_db_handler(req, res, next);
	}

	this.identify = function(req, res) {
		var app = req.app;
		for (var i = 0; i < app._router.stack.length; i++)
		{
			var stack = app._router.stack[i];
			if (!stack.route)
				continue;

			if (stack.match(req.path) && stack.route._handles_method(req.method))
			{
				var handler = {
					handler_type: 'api',
					matched_path: stack.route.path,
					check_permissions: check_permissions,
					execute: execute
				};

				app.get('logger').debug('api', 'Matched API call ' + handler.matched_path);
				return handler;
			}
		}


		return null;
	};

	this.init = function() {
		var list = load_api_calls(self.app);
		// re-organizing the array a bit
		// {
		// 	"/grape/login": {
		// 		"GET":["role","role"],
		// 		"POST:["role","role"]
		// 	}
		// }
		list.forEach(function(call) {
			if (!self.api_list[call.url])
				self.api_list[call.url] = {};
			self.api_list[call.url][call.method] = call.roles;
		});


		// load from DB
		var qry = app.get('db').query('SELECT * FROM grape.access_path');
		qry.on('row', function(row) {
			row.method.forEach(function(method) {
				if (!self.api_list[row.regex_path])
					self.api_list[row.regex_path] = {};

				if (self.api_list[row.regex_path][method])
					self.api_list[row.regex_path][method].push(row.role_name);
				else
					self.api_list[row.regex_path][method] = [row.role_name];
			});
		});
		qry.on('end', function() {
			
		});
		qry.on('error', function(err) {
		});
	};
}

module.exports = APIHandler;

