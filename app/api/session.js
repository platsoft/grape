"use strict";
var logger,
	app;

exports = module.exports = function(app_) {
	app = app_;
	logger = app.get('logger');

/**
 * @api /session/new
 * @method POST
 * @desc New session
 * @fields username TEXT, password TEXT
 * @return JSON object with fields { success: true/false, session_id, code: INTEGER (0 on success), message: TEXT } 
 */
	app.post('/session/new', create_session);

	/**
	 * @api /session/list
	 * @desc list the active sessions
	 */
	app.get('/session/list/:date', select_session);
};

function select_session(req, res) {
	var obj = { date: req.params.date};
	req.db.json_call('session_select', obj, null, {response: res});
};

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
			if (obj.success == "true")
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
			res.json({error: err});
		}
		
	});
};

