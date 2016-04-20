"use strict";
var logger;
var app;

exports = module.exports = function(app_) {
	app = app_;
	logger = app.get('logger');

	/**
 * @api /user/save
 * @method POST
 * @desc Save user
 * @return JSON object with fields { success: true/false,code: INTEGER (0 on success), new: true/false, user_id: INTEGER, message: TEXT Error message }
 */
	//app.post('/grape/user/save', save_user);
	app.post('/grape/user/save', save_user);
	app.post('/grape/user/save_password', save_user_password);
	app.post('/grape/user/toggle_user', toggle_user);
};


function save_user(req, res) {
	if(req.body.user_id)
		logger.debug('Updating user');
	else
		logger.debug('Creating user');

	var input = {
		user_id   : req.body.user_id,
		username  : req.body.username,
		fullnames : req.body.fullnames,
		email     : req.body.email,
		role_names: req.body.role_names
	};

	res.locals.db.json_call('grape.user_save', input, function(err, result) {
		if (!err)
		{
			var obj = result.rows[0]['grapeuser_save'];
			res.json(obj);
		}
		else
		{
			res.json({error: err});
		}
	});
}

function toggle_user(req, res) {
	if(req.body.user_id)
		logger.debug('Updating user');
	else
		logger.debug('Creating user');

	var input = {
		user_id   : req.body.user_id,
		active: req.body.active
	};

	res.locals.db.json_call('grape.toggle_user', input, function(err, result) {
		if (!err)
		{
			var obj = result.rows[0]['grapeuser_toggle'];
			res.json(obj);
		}
		else
		{
			res.json({error: err});
		}
	});
	return res;
}

function save_user_password(req, res) {

	if(req.body.user_id)
		logger.debug('Updating user');
	else
		logger.debug('Creating user');

	var input = {
		user_id : req.body.user_id,
		password: req.body.password,
	};

	res.locals.db.json_call('grape.user_save_password', input, function(err, result) {
		if (!err)
		{
			var obj = result.rows[0]['grapeuser_save_password'];
			res.json(obj);
		}
		else
		{
			res.json({error: err});
		}
	});
}
