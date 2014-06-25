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
};

function save_user(req, res) {
	if(req.body.user_id)
		logger.debug('Updating user');
	else		
		logger.debug('Creating user');

	var input = {
		user_id : req.body.user_id,
		username: req.body.username,
		password: req.body.password,
		fullnames: req.body.fullnames,
		email: req.body.email,
		active: req.body.active
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