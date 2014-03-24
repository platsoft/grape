
module.exports = function (app)
{
	// Session management
	app.use(function(req, res, next) {

		var db = app.get('db');
		if (!db)
		{
			next();
			return;
		}

		var accepts_json = (req.headers.accept.indexOf('application/json') != -1);
		var session_id = req.header('X-SessionID') || req.cookies.SessionID;

		//Do not do session management checking if session id is not set and the request do not want json. We need to check if it is json because it might be a guest API call
		if ((!session_id || session_id == 0) && !accepts_json)
		{
			next();
			return;
		}
		var path = req.app._router.matchRequest(req);

		path = path ? path.path : req.path;
		
		function session_fail () 
		{
			res.set('X-No-Permission', 'true');
			if (req.headers.accept.indexOf('application/json') != -1)
			{
				res.json({error: 'Internal error'});
			} 
			else
			{
				res.send('No permission to access this page. Please ask your manager to contact Platinum Software if you should have access.');
			}
			return;
		}

		db.func('session_check_path_select', session_id, path, req.method, function(err, result) { 
			if (err)
			{
				app.get('logger').session('Could not load access paths for Session ' + session_id + ' against ' + path + ' ' + err);
				session_fail();
				return;
			}

			var ret = result.rows[0];
			if (ret.error_code == 2) // invalid session
			{
				res.clearCookie('SessionID', '/');
			}
			app.get('logger').session((ret.check_path_result ? 'GRANTED' : 'DENIED') + ' ' + session_id + ' ' + path);

			req.session = ret;
			req.user_access_path = ret.user_role;
			next();
		});
	});
}

