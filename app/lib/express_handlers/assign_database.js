// Express handler
// Assign a database to the request based on res.local.session (session_id and username)
// 
// After this has ran, res.locals.db and req.db will be set accordingly

var util = require('util');
const dblib = require(__dirname + '/../db.js');

module.exports = function (req, res, next) {
	var app = req.app;
	if (!app.dbs)
		app.dbs = {};
	
	// defaults
	req.db = app.get('guest_db');
	res.locals.db = req.db;

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
	var username = res.locals.session.username;

	// does one exist in the cache?
	if (app.dbs[session_id])
	{
		app.get('logger').session('debug', 'Using existing database connection for session', res.locals.session.session_id, 'user', res.locals.session.username);
		req.db = app.dbs[session_id];
		res.locals.db = app.dbs[session_id];
		if (app.dbs[session_id].state == 'connecting')
		{
			app.dbs[session_id].on('connected', function() {
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
		app.get('logger').session('debug', 'Creating a database connection for session', res.locals.session.session_id, 'user', res.locals.session.username);
		var db = new dblib({
			dburi: app.get('config').dburi, 
			session_id: session_id,
			username: username,
			db_idle_timeout: app.get('config').db_idle_timeout || 10000,
			debug: app.get('config').debug
		});

		app.dbs[session_id] = db;
		db.on('connected', function() {
			req.db = app.dbs[session_id];
			res.locals.db = app.dbs[session_id];
			next();
		});
		db.on('end', function(obj) {
			if (obj.session_id != null)
			{
				if (app.dbs[obj.session_id])
					app.dbs[obj.session_id] = null;
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


