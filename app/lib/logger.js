
var _ = require('underscore');
var fs = require('fs');

var logger = function(opts) {
	var options = _.extend(opts, {
	});
	this.options = options;

	var streams = new Object();
	this.streams = streams;
};

logger.prototype._join_arguments = function(args) {
	var ret = [];
	for (var i = 0; i < args.length; i++)
	{
		if (typeof args[i] == 'string')
			ret.push(args[i]);
		else if (args[i].toString)
			ret.push(args[i].toString());
		else
			ret.push(args[i]);
			
	}
	return ret.join('');
};

logger.prototype.session = function(message) {
	this.log('session', message, {});
};
logger.prototype.info = function(message) {
	this.log('info', message, {});
};
logger.prototype.trace = function(message) {
	this.log('trace', message, {});
};
logger.prototype.debug = function(message) {
	this.log('debug', message, {});
};
logger.prototype.db = function(message) {
	this.log('db', message, {});
};
logger.prototype.error = function() {
	this.log('error', logger.prototype._join_arguments(arguments), {});
};



logger.prototype.log = function(level, message, opts) {
	if (process.stdout.isTTY)
	{
		console.log(level + ": " + message);
	}
	this.logToStream('all', message);
	this.logToStream(level, message);
};

logger.prototype.logToStream = function(streamname, message) {
	var d = new Date();
	var stream = this.getWriteStream(streamname);
	stream.write(d.toJSON());
	stream.write(' ');
	stream.write(message);
	stream.write("\n");
};

logger.prototype.getWriteStream = function(level) {
	if (typeof this.streams[level] == 'undefined' || !this.streams[level])
	{
		var d = new Date();
		var fname = [this.options.log_directory, '/', level, '-', d.getFullYear(), (d.getMonth()+1).toString(), d.getDate(), '.log'].join('');
		
		this.streams[level] = fs.createWriteStream(fname, {flags: 'a'});

		//TODO if we want to somewherein the future move old files to other dir
	}

	return this.streams[level];
};

exports = module.exports = logger;

