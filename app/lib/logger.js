
var _ = require('underscore');

var logger = module.exports;

logger = function(opts) {
	var options = _.extend(opts, {
	});
	this.options = options;
};

logger.session = function(message) {
	this.log('session', message, []);
};

logger.log = function(level, message, outputs) {
	console.log(level + ": " + message);
};



