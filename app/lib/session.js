
var util = require('util');

module.exports = function (app)
{
	var dbs = [];
	app.set('dbs', dbs);

	// Session management
	app.use(function(req, res, next) {


		var db = app.get('db');
		if (!db)
		{
			next();
			return;
		}
		
		var accepts_json = (req.headers.accept.indexOf('application/json') != -1);
		var session_id = req.header('X-SessionID') || req.cookies.session_id;

		//Do not do session management checking if session id is not set and the request do not want json. We need to check if it is json because it might be a guest API call
		if ((!session_id || session_id == 0) && !accepts_json)
		{
			next();
			return;
		}

		//find the route that matches this request
		var path = req.url;
		for (var i = 0; i < app._router.stack.length; i++)
		{
			if (!app._router.stack[i].route) continue;
			var stack = app._router.stack[i];
			var route = stack.route;
			if (stack.match(req.path))
			{
				console.log("MATCHED " + req.path + " TO " + route.path);
				path = route.path;
				break;
			}
		}

		
		function session_fail () 
		{
			res.set('X-No-Permission', 'true');
			if (req.headers.accept.indexOf('application/json') != -1)
			{
				res.json({error: 'Permission denied', code: "-1"});
			} 
			else
			{
				res.send('No permission to access this page. Please ask your manager to contact Platinum Software if you should have access.');
			}
			return;
		}

		function handle_session_check (ret)
		{
			if (ret.error_code == 2) // invalid session
			{
				res.clearCookie('session_id', '/');
			}

			var user_id = ret.user_id;

			app.get('logger').session((ret.check_path_result ? 'GRANTED' : 'DENIED') + ' ' + session_id + ' ' + path);

			if (!ret.check_path_result)
			{
				session_fail();
				return;
			}

			req.session = ret;
			req.user_access_path = ret.user_role;

			res.locals.session = ret;

			var dbs = app.get('dbs');
			if (dbs[session_id])
			{
				req.db = dbs[session_id];
				res.locals.db = dbs[session_id];
				next();
			}
			else
			{
				var _db = require(__dirname + '/db.js');
				var db = new _db({
					dburi: app.get('config').dburi, 
					debug: app.get('config').debug,
					debug_logger: function(s) { app.get('logger').db(s); },
					error_logger: function(s) { app.get('logger').db(s); }
				});

				dbs[session_id] = db;
				db.on('connected', function() {
					db.json_call('grape.set_session_user_id', {user_id: user_id}, function(d) { 
						req.db = dbs[session_id];
						res.locals.db = dbs[session_id];
						next();
					});
				});
			}
		}

		app.get('logger').session('Checking path ' + path + ' against session ' + session_id);

		function check_session_path_in_database (session_id, path, method, cb)
		{
			db.query('SELECT * FROM grape.session_check_path_select($1, $2, $3)', [session_id, path, method], cb);
		}

		var cache = app.get('cache');
		if (!cache)
		{
			check_session_path_in_database(session_id, path, req.method, function(err, result) {
				if (err)
				{
					app.get('logger').session('Could not load access paths for Session ' + session_id + ' against ' + path + ' ' + err);
					session_fail();
					return;
				}

				handle_session_check(result.rows[0]);
			});

		}
		else
		{
			var cachename = [session_id, path, req.method].join('-');
			app.get('cache').fetch(cachename, function(message) {
				if (typeof message.v == 'undefined' || !message.v)
				{
					check_session_path_in_database(session_id, path, req.method, function(err, result) {
						if (err)
						{
							app.get('logger').session('Could not load access paths for Session ' + session_id + ' against ' + path + ' ' + err);
							session_fail();
							return;
						}

						var ret = result.rows[0];
						app.get('cache').set(cachename, ret);
						handle_session_check(ret);
					});
				}
				else
				{
					console.log("FOUND THIS QUERY IN CACHE");
					handle_session_check(message.v);
				}
			});
		}
	});
}



