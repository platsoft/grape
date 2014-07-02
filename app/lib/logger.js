
var _ = require('underscore');


var logger = function(opts) {
	var options = _.extend(opts, {
	});
	this.options = options;
};

logger.session = function(message) {
	this.log('session', message, []);
};

logger.info = function(message) {
	this.log('info', message, []);
};
logger.trace = function(message) {
	this.log('trace', message, []);
};
logger.debug = function(message) {
	this.log('debug', message, []);
};




logger.log = function(level, message, outputs) {
	console.log(level + ": " + message);
};

exports = module.exports = logger;
