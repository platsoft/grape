"use strict";
var logger;
var app;

const ldap = require('ldapjs');

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
 * @url /grape/login_remotely
 * @method POST
 * @desc 
 * @sqlfunc grape.session_insert
 * @body
 * { 
 * 	username TEXT Username
 * 	password TEXT Password
 * }
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/grape/login_with_remote', login_via_ldap);


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

	res.locals.db.json_call('grape.session_insert', obj, function(err, result) {
		result = result.rows[0].grapesession_insert;
		if (result.status == 'OK')
		{
			res.set('Set-Cookie', 'session_id=' + result.session_id + '; path=/; HttpOnly');
			res.json(result);
		}
		else
		{
			res.json(result);
		}
	});
}

function login_via_ldap (req, res)
{
	var ip_address = req.ip;

	var auth_server = req.body.auth_server;

	var obj = {
		password: req.body.password,
		ip_address: ip_address,
		auth_server: auth_server
	};
	
	if (req.body.email)
	{
		obj.email = req.body.email;
		app.get('logger').session('info', 'login attempt from [', obj.email, ']@', ip_address);
	}
	else if (req.body.username)
	{
		obj.username = req.body.username;
		app.get('logger').session('info', 'login attempt from ', obj.username, '@', ip_address);
	}
	else
	{
		res.json({'status': 'ERROR', 'message': 'Invalid input'}).end();
		return;
	}

	//TODO check that auth_server starts with ldap:// or ldaps://
	
	res.locals.db.query('SELECT shared_secret FROM grape.service WHERE service_name=$1', [auth_server], function(err, result) {

		if (err || !result)
		{
			res.json({status: 'ERROR'}).end();
			return;
		}

		if (result.rows.length == 0)
		{
			res.json({status: 'ERROR', message: 'Service not found in registry', code: -1}).end();
			return;
		}

		var result = result.rows[0];

		var ldapclient = ldap.createClient({
			url: auth_server
		});

		client.bind('cn=root', result.shared_secret, function(err) {
			if (err)
			{
				res.status(200).json({'status': 'ERROR', message: 'LDAP error', error: err});
				return;
			}

			var dn = ['uid=' + obj.username, 'o=platsoft,ou=Users'].join(',');

			client.bind(dn, req.body.password, function(err) {
				if (err)
				{
					res.status(200).json({'status': 'ERROR', message: 'LDAP error', error: err});
					return;
				}

				res.locals.db.json_call('grape.create_session_from_remote', obj, function(err, result) {
					result = result.rows[0].create_session_from_remote;
					if (result.status == 'OK')
					{
						res.set('Set-Cookie', 'session_id=' + result.session_id + '; path=/; HttpOnly');
						res.json(result);
					}
					else
					{
						res.json(result);
					}
				});
			});
		});
	});
}



function login_with_service_ticket (req, res)
{
	var ip_address = req.ip;

	if (typeof req.body.service_ticket == "undefined")
	{
		app.get('logger').session('info', 'invalid parameters sent to /grape/login_with_ticket', req.body);
		res.json({'status': "error", code: -1, "message": "invalid parameters"});
		return;
	}

	var obj = {
		service_ticket: req.body.service_ticket,
		ip_address: ip_address
	};

	res.locals.db.jsonb_call('grape.create_session_from_service_ticket', obj, function(err, result) {
		result = result.rows[0].grapecreate_session_from_service_ticket;
		if (result.status == 'OK')
		{
			res.set('Set-Cookie', 'session_id=' + result.session_id + '; path=/; HttpOnly');
			res.json(result);
		}
		else
		{
			res.json(result);
		}

	});
}


function logout (req, res)
{
	res.set('Set-Cookie', 'session_id=; path=/; HttpOnly');
	req.db.json_call('grape.logout', {session_id: req.query.session_id || req.session_id}, null, {response: res});
}


function session_ping(req, res)
{
	req.db.json_call('grape.session_ping', {'session_id': req.query.session_id}, null, {response: res});
}


