
var string_util = function(){ };

string_util.prototype.trim = function(str) { 
	return str.replace(/^[\s]+/, '').replace(/[\s]+$/, '');
};

module.exports = string_util;


