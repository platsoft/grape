
var colors = require('colors');

module.exports = {};

module.exports.print_ok = function(str) {
	console.log(colors.green(str));
};

module.exports.print_error = function(str) {
	console.log(colors.red(str));
};


