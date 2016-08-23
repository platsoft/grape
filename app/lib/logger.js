
var _ = require('underscore');
var fs = require('fs');
var util = require('util');

/**
 * levels:
 * 	debug (and the default log level)
 * 	trace
 * 	info
 * 	warn
 * 	error
 *
 * channels:
 * 	app - app related messages (and the default log channel)
 * 	api - api related messages
 * 	session - session related messages
 * 	db - database related messages
 * 	comms - cache and comms related messages
 */

var logger = function(opts) {
	var self = this;
	this.self = self;

	var options = _.extend(opts, {
	});
	this.options = options;

	var streams = new Object();
	this.streams = streams;

	this.levels = ['debug', 'info', 'warn', 'error'];
	this.channels = ['api', 'app', 'session', 'db', 'comms'];

	this._join_args = function(args, skip) {
		var ret = [];
		for (var i = skip || 0; i < args.length; i++)
			ret.push(args[i]);
		return ret;
	};

	this.session = function() {
		var args = ['session'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.db = function() {
		var args = ['db'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};

	this.info = function() {
		var args = ['info'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.trace = function() {
		var args = ['trace'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.debug = function() {
		var args = ['debug'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.error = function() {
		var args = ['error'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.warn = function() {
		var args = ['warn'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};


	//
	//provide a channel (default to app), loglevel (default to app) and message
	this.log = function() {

		var channel = 'app';
		var level = 'debug';
		var message_list = [];

		if (arguments[0])
		{
			if (typeof arguments[0] == 'string')
			{
				var str = arguments[0];
				if (self.levels.indexOf(str) >= 0)
					level = str;
				else if (self.channels.indexOf(str) >= 0)
					channel = str;
				else
					message_list.push(str);
			}
			else
				message_list.push(str);
		}

		if (arguments[1])
		{
			if (typeof arguments[1] == 'string')
			{
				var str = arguments[1];
				if (self.levels.indexOf(str) >= 0)
					level = str;
				else if (self.channels.indexOf(str) >= 0)
					channel = str;
				else
					message_list.push(str);
			}
			else
				message_list.push(str);
		}

		for (var i = 2; i < arguments.length; i++)
			message_list.push(arguments[i]);

		var ar = [];
		for (var i = 0; i < message_list.length; i++)
		{
			if (typeof message_list[i] == 'string')
				ar.push(message_list[i]);
			else
				ar.push(util.inspect(message_list[i]));
		}
		
		var message = ar.join(' ');

		var streamname = channel + '-' + level;

		if (process.stdout.isTTY)
		{
			console.log(streamname + ": " + message);
		}
		self.logToStream('all', streamname + ": " + message);
		self.logToStream(streamname, message);
	};

	this.logToStream = function(streamname, message) {
		var d = new Date();
		var d_str = ['[', d.getFullYear(), '/', ('00' + (d.getMonth()+1)).slice(-2), '/', ('00' + d.getDate()).slice(-2), ' ', ('00' + d.getHours()).slice(-2), ':', ('00' + d.getMinutes()).slice(-2), ':', ('00' + d.getSeconds()).slice(-2), ']'].join('');

		var data = [d_str, ' ', message, "\n"].join('');

		var stream = self.getWriteStream(streamname);
		stream.write(data);
	};

	this.getWriteStream = function(streamname) {
		if (typeof self.streams[streamname] == 'undefined' || !self.streams[streamname])
		{
			var d = new Date();
			var fname = [self.options.log_directory, '/', streamname, '-', d.toJSON().slice(0, 10).replace(/\-/g, ''), '.log'].join('');
			
			self.streams[streamname] = fs.createWriteStream(fname, {flags: 'a'});

			var symlinkname = [self.options.log_directory, '/', streamname, '-current.log'].join('');
			try {
				fs.unlinkSync(symlinkname);
			} catch (e) { }
				
			try {
				fs.symlinkSync(fname, symlinkname);
			} catch (e) { console.log(e); }
		}

		return self.streams[streamname];
	};
};

exports = module.exports = logger;

