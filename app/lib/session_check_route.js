
// This handler will check that the existing session (based on X-SessionID header) are allowed to execute the route it requested

var util = require('util');

module.exports = function (req, res, next) {
	var app = req.app;

	var db = app.get('db');
	if (!db)
	{
		next();
		return;
	}
	
	var session_id = req.session_id;

	//Do not do session management checking if session id is not set and the request do not want json. We need to check if it is json because it might be a guest API call
	if ((!session_id || session_id == 0) && !req.accepts_json)
	{
		next();
		return;
	}

	/* 
	* handles the result of a session check. 
	* input must have a result_code (0 for success), user_id and session_id
	*/
	function handle_session_check (ret)
	{
		res.set('X-Permission-Code', ret.result_code);

		// Permission denied
		if (ret.result_code != 0)
		{
			res.set('X-No-Permission', 'true');

			var error_message = '';
			if (ret.result_code == 1)
			{  // invalid session
				res.status(403);
				error_message = 'Invalid session';
			}
			else if (ret.result_code == 2)
			{ // permission denied
				res.status(403);
				error_message = 'Permission denied';
			}
			else if (ret.result_code == 9)
			{ // path not found and default_access_allowed is false
				res.status(403);
				error_message = 'Path not found and default_access_allowed is false';
			}
			else
			{
				res.status(403);
			}
			
			res.set('X-Permission-Error', error_message);


			if (req.headers.accept.indexOf('application/json') != -1)
				res.json({status: 'ERROR', message: error_message, code: ret.result_code});
			else
				res.send(error_message);

			return;
		}


		var user_id = ret.user_id;
		var session_id = ret.session_id;

		// not logged in and access granted
		if (session_id == null)
		{
			req.db = res.locals.db = app.get('guest_db');
			next();
			return;
		}

		res.locals.session = ret;

	}


	function check_session_path_in_database (session_id, path, method, cb)
	{
		app.get('logger').session('info', 'Checking path ' + path + ' against session ' + session_id);
		db.query('SELECT * FROM grape.check_session_access($1, $2, $3)', [session_id, path, method], function(err, result) {
			if (err)
			{
				app.get('logger').error('Could not load access paths for session ' + session_id + ' against ' + path + ' ' + err);

				ret = {};

				return;
			}

			var ret = result.rows[0];
		
			app.get('logger').session((ret.result_code == 0 ? 'GRANTED' : 'DENIED') + ' ' + session_id + ' ' + path);

			cb(ret);
		});
	}

	var cache = app.get('cache');
	if (!cache)
	{
		check_session_path_in_database(session_id, req.matched_path, req.method, function(result) {
			handle_session_check(result);
		});
	}
	else
	{
		//create a cachename JMORI51EA94M8AZ-/session/new-POST
		var cachename = [session_id, req.matched_path, req.method].join('-');
		app.get('cache').fetch(cachename, function(message) {
			if (typeof message.v == 'undefined' || !message.v)
			{
				check_session_path_in_database(session_id, req.matched_path, req.method, function(result) {

					//only save on access allowed
					if (result.result_code == 0)
					{
						app.get('cache').set(cachename, result);
					}
					handle_session_check(result);
				});
			}
			else
			{
				handle_session_check(message.v);
			}
		});
	}
};

