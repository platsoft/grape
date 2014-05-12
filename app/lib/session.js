
module.exports = function (app)
{

	var dbs = [];
	app.set('dbs', dbs);

	// Session management
	app.use(function(req, res, next) {

		app.get('logger').session('aaaa');

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
		var path = req.app._router.matchRequest(req);

		path = path ? path.path : req.path;
		
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

		app.get('logger').session('Checking path ' + path + ' against session ' + session_id);

		db.query('SELECT * FROM grape.session_check_path_select($1, $2, $3)', [session_id, path, req.method], function(err, result) { 
			if (err)
			{
				app.get('logger').session('Could not load access paths for Session ' + session_id + ' against ' + path + ' ' + err);
				session_fail();
				return;
			}

			var ret = result.rows[0];
			if (ret.error_code == 2) // invalid session
			{
				res.clearCookie('session_id', '/');
			}
			app.get('logger').session((ret.check_path_result ? 'GRANTED' : 'DENIED') + ' ' + session_id + ' ' + path);

			if (!ret.check_path_result)
			{
				session_fail();
				return;
			}

			req.session = ret;
			req.user_access_path = ret.user_role;

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
				var db = new _db({dburi: app.get('config').dburi, debug: app.get('config').debug});

				dbs[session_id] = db;
				db.on('connected', function() {
					req.db = dbs[session_id];
					res.locals.db = dbs[session_id];
					next();
				});
			}
		});
	});
}



