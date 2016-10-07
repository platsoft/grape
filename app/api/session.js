"use strict";
var logger,
	app;

exports = module.exports = function(app_) {
	app = app_;
	logger = app.get('logger');



/**
 * @url /grape/login
 * @method POST
 * @desc Create a new session for the user if the username and password provided matches a valid active user in the system
 * @body
 * { 
 * 	username TEXT Username
 * 	password TEXT Password
 * }
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/login', login);

/**
 * @url /grape/logout
 * @method POST
 * @desc Logout
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/logout', logout);


/**
 * @url /session/list
 * @desc List all active sessions
 */
	app.get('/session/list/:date', select_session);

/**
 * @url /grape/session_ping
 * @param session_id Session ID to check
 * @desc Retrieve current server and session information
 */
	app.get('/grape/session_ping', session_ping);


/**
 * @url /session/new
 * @deprecated
 * @method POST
 * @desc New session
 * @fields username TEXT, password TEXT
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/session/new', create_session);

};

function select_session(req, res) {
	var obj = { date: req.params.date};
	req.db.json_call('session_select', obj, null, {response: res});
};

function login (req, res)
{
	if ((typeof req.body.username == "undefined" && typeof req.body.email == "undefined") || typeof req.body.password == "undefined")
	{
		res.json({'status': "ERROR", code: -1, "message": "Invalid parameters"});
		return;
	}
	
	var ip_address = req.connection.remoteAddress;

	var obj = {
		password: req.body.password,
		ip_address: ip_address
	};
	
	if (req.body.email)
	{
		obj.email = req.body.email;
		app.get('logger').session('Login attempt from [', obj.email, ']@', ip_address);
	}
	else
	{
		obj.username = req.body.username;
		app.get('logger').session('Login attempt from ', obj.username, '@', ip_address);
	}

	

	res.locals.db.json_call('grape.session_insert', obj, null, {response: res});
}

function logout (req, res)
{
	req.db.json_call('grape.logout', {session_id: req.session_id}, null, {response: res});
}

function session_ping(req, res)
{
	req.db.json_call('grape.session_ping', {'session_id': req.query.session_id}, null, {response: res});
}



function create_session(req, res) {
	app.get('logger').debug('Creating session');
	var success = false;
	var user = req.body.username;
	var password = req.body.password ? req.body.password : '';
	
	var obj = {
		username: user,
		password: password,
		ip_address: req.connection.remoteAddress
	};

	res.locals.db.json_call('grape.session_insert', obj, function(err, result) {
		if (!err)
		{
			var obj = result.rows[0]['grapesession_insert'];
			if (obj.success === true || obj.success == "true")
			{
				//1 month
				res.cookie('session_id', obj.session_id, {maxAge: 30 * 24 * 60 * 60 * 1000});
				res.cookie('user_id', obj.user_id, {maxAge: 30 * 24 * 60 * 60 * 1000});
			}
			else
			{
				res.clearCookie('session_id');
				res.clearCookie('user_id');
			}
			res.json(obj);
		}
		else
		{
			app.get('logger').error('Error while creating session: ', err);

			res.json({error: err});
		}
		
	});
};


