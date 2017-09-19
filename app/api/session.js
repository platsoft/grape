"use strict";
var logger;
var app;

exports = module.exports = function(_app) {
	app = _app;
	logger = app.get('logger');


/**
 * @url /grape/login
 * @method POST
 * @desc Create a new session for the user if the username and password provided matches a valid active user in the system
 * @sqlfunc grape.session_insert
 * @body
 * { 
 * 	username TEXT Username
 * 	password TEXT Password
 * }
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/login', login);

/**
 * @url /grape/login_with_ticket
 * @method POST
 * @desc Create a new session for the user with a service ticket
 * @sqlfunc grape.create_session_from_service_ticket
 * @body
 * { 
 * 	service_ticket TEXT encrypted service ticket
 * }
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/login_with_ticket', login_with_service_ticket);

/**
 * @url /grape/set_password_with_service_ticket
 * @method POST
 * @desc Reset password for the user with a service ticket
 * @sqlfunc grape.create_session_from_service_ticket
 * @body
 * { 
 * 	service_ticket TEXT encrypted service ticket
 * }
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/reset_password_with_ticket', set_password_with_service_ticket);


/**
 * @url /grape/logout
 * @method POST
 * @desc Logout
 * @sqlfunc grape.logout
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
 * @method GET
 * @param session_id Session ID to check
 * @sqlfunc grape.session_ping
 * @desc Retrieve current server and session information
 */
	app.get('/grape/session_ping', session_ping);

};

function select_session(req, res) {
	var obj = { date: req.params.date};
	req.db.json_call('session_select', obj, null, {response: res});
};

function login (req, res)
{
	if ((typeof req.body.username == "undefined" && typeof req.body.email == "undefined") || typeof req.body.password == "undefined")
	{
		app.get('logger').session('info', 'invalid parameters sent to /grape/login', req.body);
		res.json({'status': "error", code: -1, "message": "invalid parameters"});
		return;
	}
	
	var ip_address = req.ip;

	var obj = {
		password: req.body.password,
		ip_address: ip_address
	};
	
	if (req.body.email)
	{
		obj.email = req.body.email;
		app.get('logger').session('info', 'login attempt from [', obj.email, ']@', ip_address);
	}
	else
	{
		obj.username = req.body.username;
		app.get('logger').session('info', 'login attempt from ', obj.username, '@', ip_address);
	}

	res.locals.db.json_call('grape.session_insert', obj, null, {response: res});
}


function login_with_service_ticket (req, res)
{
	if (typeof req.body.service_ticket == "undefined")
	{
		app.get('logger').session('info', 'invalid parameters sent to /grape/login_with_ticket', req.body);
		res.json({'status': "error", code: -1, "message": "invalid parameters"});
		return;
	}
	
	var ip_address = req.ip;

	var obj = {
		service_ticket: req.body.service_ticket,
		ip_address: ip_address
	};
	
	res.locals.db.jsonb_call('grape.create_session_from_service_ticket', obj, null, {response: res});
}



function set_password_with_service_ticket (req, res)
{
	if (typeof req.body.service_ticket == "undefined")
	{
		app.get('logger').session('info', 'invalid parameters sent to /grape/reset_password_with_ticket', req.body);
		res.json({'status': "error", code: -1, "message": "invalid parameters"});
		return;
	}
	
	var ip_address = req.ip;

	console.log('set_password_with_service_ticket');
	console.log(req.body);

	var obj = {
		service_ticket: req.body.service_ticket,
		ip_address: ip_address,
		password: req.body.password
	};
	
	res.locals.db.jsonb_call('grape.set_password_with_service_ticket', obj, null, {response: res});
}




function logout (req, res)
{
	req.db.json_call('grape.logout', {session_id: req.session_id}, null, {response: res});
}

function session_ping(req, res)
{
	req.db.json_call('grape.session_ping', {'session_id': req.query.session_id}, null, {response: res});
}



