// Express handler
// Assign a database to the request based on res.local.session (session_id and user_id)
// 
// After this has ran, res.locals.db and req.db will be set accordingly

var util = require('util');

module.exports = function (req, res, next) {
	var app = req.app;
	if (!app.get('dbs'))
		app.set('dbs', []);
	
	var dbs = app.get('dbs'); //DB cache

	var db = app.get('db'); // If the app doesn't have a DB - do not continue
	if (!db)
	{
		next();
		return;
	}
	
	//Do not change the db connection if no session is set
	if (!res.locals.session || !res.locals.session.session_id)
	{
		next();
		return;
	}

	var session_id = res.locals.session.session_id;
	var user_id = res.locals.session.user_id;

	// does one exist in the cache?
	if (dbs[session_id])
	{
		req.db = dbs[session_id];
		res.locals.db = dbs[session_id];
		if (dbs[session_id].state == 'connecting')
		{
			dbs[session_id].on('connected', function() {
				next();
			});
		}
		else
		{
			next();
		}
	}
	else
	{
		var _db = require(__dirname + '/db.js');
		var db = new _db({
			dburi: app.get('config').dburi, 
			session_id: session_id,
			user_id: user_id,
			timeout: 10000,
			debug: app.get('config').debug
		});

		dbs[session_id] = db;
		db.on('connected', function() {
			req.db = dbs[session_id];
			res.locals.db = dbs[session_id];
			next();
		});
		db.on('end', function(obj) {
			if (obj.session_id != null)
			{
				var dbs = app.get('dbs');
				if (dbs[obj.session_id])
					dbs[obj.session_id] = null;
			}
		});
		db.on('error', function(err) {
			app.get('logger').log('db', 'error', err);
		});
		db.on('debug', function(msg) {
			app.get('logger').log('db', 'debug', msg);
		});
	}
};


