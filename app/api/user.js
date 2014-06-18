"use strict";
var logger;
var app;

exports = module.exports = function(app_) {
	app = app_;
	logger = app.get('logger');
};


