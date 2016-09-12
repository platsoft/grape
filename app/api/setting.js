"use strict";
var logger,
	app;

exports = module.exports = function(app_) {
	app = app_;
	logger = app.get('logger');


/**
 * @url /grape/settings
 * @method GET
 * @sqlfunc grape.list_settings
 * @desc Gets list of all known settings
 * @return Standard Grape JSON result object with added array field "settings" { name, value, json_value, hidden, description, data_type }
 */
	app.get('/grape/settings', get_settings);

/**
 * @url /grape/save_setting
 * @method POST
 * @sqlfunc grape.save_setting
 * @body {
 * 	name TEXT
 * 	value TEXT
 * 	json_value JSON
 * 	description TEXT
 * 	data_type TEXT
 * 	hidden BOOLEAN
 * }
 * @desc Saves setting
 * @return Standard Grape JSON result object 
 */
	app.post('/grape/save_setting', save_setting);

};

function get_settings(req, res)
{
	req.db.json_call('grape.list_settings', {}, null, {response: res});
}

function save_setting(req, res)
{
	req.db.json_call('grape.save_setting', req.body, null, {response: res});
}


