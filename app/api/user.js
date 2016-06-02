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
	app.post('/grape/user/save', save_user);

	/**
 * @api /user/reset_password
 * @method POST
 * @desc Reset a user password - need to get email address and username as valid inputs
 * @return 
 */
	app.post('/user/reset_password', user_reset_password);

};

function save_user(req, res) {
	var input = {
		user_id: req.body.user_id,
		username: req.body.username,
		password: req.body.password,
		fullnames: req.body.fullnames,
		email: req.body.email,
		active: req.body.active,
		role_names: req.body.role_names,
		employee_guid: req.body.employee_guid || null,
		employee_info: req.body.employee_info || null
	};

	res.locals.db.json_call('grape.user_save', input, null, {response: res});
}

function user_reset_password (req, res) 
{
	res.locals.db.json_call('grape.user_reset_password', input, null, {response: res});
}

