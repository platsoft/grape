"use strict";
var db;
var app;

exports = module.exports = function(_app) {
	app = _app;
	db = app.get('db');

/**
 * @desc
 * @method 
 * @url /grape/api_list
 *
 * @return JSON object 
 **/
	app.get("/grape/api_list", api_grapeapi_list);
};

function api_grapeapi_list(req, res)
{
	res.status(200).jsonp(app.routes);
}


