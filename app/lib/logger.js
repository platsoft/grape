
var _ = require('underscore');
var fs = require('fs');

var logger = function(opts) {
	var options = _.extend(opts, {
	});
	this.options = options;

	var streams = new Object();
	this.streams = streams;
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
		var fname = [this.options.log_directory, '/', level, '.log'].join('');
		if (fs.existsSync(fname))
		{
			var d = new Date();
			
			var ofname = [
				this.options.log_directory, 
				'/', 
				level, 
				'-', 
				d.getFullYear(), (d.getMonth()+1).toString(), d.getDate(), 'T', (d.getHours()+1), d.getMinutes(), d.getSeconds(),
				'.log'].join('');

			fs.renameSync(fname, ofname);
		}
		
		this.streams[level] = fs.createWriteStream(fname, {flags: 'w'});
	}

	return this.streams[level];
};

exports = module.exports = logger;

