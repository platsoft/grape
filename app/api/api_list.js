"use strict";
var db;
var app;
var fs = require('fs');
var express = require('express');
var _ = require('underscore');

exports = module.exports = function(_app) {
	app = _app;
	db = app.get('db');

/**
 * @desc Return a list of all API calls on this instance
 * @method GET
 * @url /grape/api_list
 * @return JSON object 
 **/
	app.get("/grape/api_list", api_grapeapi_list);

/**
 * @desc Return a list of all API calls on this instance
 * @method GET
 * @url /grape/api_list
 * @return JSON object 
 **/
	app.get("/grape/get_api", api_grapeapi_get);
};

function api_grapeapi_list(req, res)
{
	res.status(200).jsonp(app.routes);
}

function api_grapeapi_get(req, res)
{
	var api_obj = {};
	var list_of_apis = [];

	console.log('-------------');
	console.log(app._router.stack);
	// console.log(app._router.stack[0]);
	// console.log(app._router.stack[0].route.Route);
	// console.log(app._router.stack[0].route[0]);

	res.status(200).jsonp(api_obj);
}
