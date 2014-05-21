
var gutil = function(){ };

gutil.prototype.trim = function(str) { 
	return str.replace(/^[\s]+/, '').replace(/[\s]+$/, '');
};
gutil.prototype.formatDate = function(dte) { 
	if (!dte)
		return '';
	var y = dte.getFullYear();
	var m = dte.getMonth() + 1;
	var d = dte.getDate();
	return y + '/' + (m < 10 ? '0' : '') + m + '/' + (d < 10 ? '0' : '') + d;
};
gutil.prototype.formatDateTime = function(dte) {
	if (!dte)
		return '';
	var y = dte.getFullYear();
	var m = dte.getMonth() + 1;
	var d = dte.getDate();
	var mm = dte.getMinutes();
	var hh = dte.getHours();

	return y + '/' + (m < 10 ? '0' : '') + m + '/' + (d < 10 ? '0' : '') + d + ' ' + (hh < 10 ? '0' : '') + hh + ':' + (mm < 10 ? '0' : '') + mm;
}



module.exports = gutil;


