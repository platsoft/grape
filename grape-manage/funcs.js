
var colors = require('colors');

module.exports = {};

module.exports.print_ok = function(str) {
	console.log(colors.green(str));
};

module.exports.print_error = function(str) {
	console.log(colors.red(str));
};

module.exports.print_warn = function(str) {
	console.log(colors.yellow(str));
};


// align left
module.exports.align = function(str, length) {
	if (!str)
		var ret = '';
	else
		var ret = str.toString();
	for (var i = ret.length; i < length; i++)
		ret = ret + ' ';
	return ret;
};


