"use strict";
var db;
var app;

exports = module.exports = function(_app) {
	app = _app;
	db = app.get('db');

/**
 * @desc Sends an email
 * @method POST
 * @url /grape/send_mail
 * @sqlfunc grape.send_email
 * @body 
 * {
 * 	to TEXT Email address of recipient
 *	template TEXT Template name to use
 *	template_data JSON Template data to use
 *	headers JSON Set of custom headers optional
 * }
 * @return Standard JSON result
 **/
	app.post("/grape/send_mail", api_send_mail);
};

function api_send_mail(req, res)
{
	res.locals.db.json_call('grape.send_email', req.body, null, {response: res});
}


