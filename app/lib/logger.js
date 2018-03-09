
const _ = require('underscore');
const fs = require('fs-extra');
const util = require('util');
const path = require('path');

/**
 * levels:
 * 	debug (and the default log level)
 * 	info
 * 	warn
 * 	err
 * 	crit
 * 	alert
 * 	emerg
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

	var local_log_stream = null;
	this.local_log_stream = local_log_stream;
	this.local_log_stream_date = null;

	this.levels = ['emerg', 'alert', 'crit', 'err', 'warn', 'notice', 'info', 'debug'];
	this.channels = ['api', 'app', 'session', 'db', 'comms'];

	this.level_aliases = {
		'trace': 'info',
		'error': 'err',
	};

	this.level_tty_colors = {
		'emerg': "\033[31m", 
		'alert': "\033[35m", 
		'crit': "\033[31m", 
		'err': "\033[31m", 
		'warn': "\033[33m",
		'notice': "\033[34m",
		'info': "\033[32m",
		'debug': "\033[37m"
	};
	this.channel_tty_colors = {'api': "\033[42m", 'app': "\033[43m", 'session': "\033[47m", 'db': "\033[45m", 'comms': "\033[46m"};

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
	this.app = function() {
		var args = ['app'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.api = function() {
		var args = ['api'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.comms = function() {
		var args = ['comms'].concat(self._join_args(arguments));
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
	this.err = this.error;
	this.warn = function() {
		var args = ['warn'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.emerg = function() {
		var args = ['emerg'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.crit = function() {
		var args = ['crit'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};
	this.alert = function() {
		var args = ['alert'].concat(self._join_args(arguments));
		self.log.apply(self, args);
	};




	//
	//provide a channel (default to app), loglevel (default to debug) and message
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
				else if (self.level_aliases[str])
					level = self.level_aliases[str];
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
				else if (self.level_aliases[str])
					level = self.level_aliases[str];
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

		if (level == 'debug' && self.options.debug == false)
			return;
		
		var message = ar.join(' ');

		self.log_event(level, channel, message);
	};

	this.get_local_log_file = function() {
		var d = new Date();

		// TODO use momentjs
		var date_now = [d.getFullYear(), 
			('00' + (d.getMonth()+1)).slice(-2), 
			('00' + d.getDate()).slice(-2)
		].join('');

		if (!self.local_log_stream || date_now != self.local_log_stream_date)
		{
			var s = 'master';
			if (process.env.state)
				s = process.env.state;
		
			var logfilename = [s, '-', process.pid, '-', date_now, '.log'].join('');
			var logdirectory = path.join(
				self.options.log_directory, 
				d.getFullYear().toString(), 
				('00' + (d.getMonth()+1)).slice(-2), 
				('00' + d.getDate()).slice(-2)
			);

			fs.ensureDirSync(logdirectory);

			var fullname = path.join(logdirectory, logfilename);

			if (self.local_log_stream)
				self.local_log_stream.end();

			self.local_log_stream = fs.createWriteStream(fullname, {flags: 'a'});
			self.local_log_stream_date = date_now;
		}
		
		return self.local_log_stream;
	};

	this.log_event = function(level, channel, message) {
		if (process.stdout.isTTY)
		{
			var s = 'master';
			if (process.env.state)
				s = process.env.state;

			var proc_bg_color_code = "\033[47;34m";
			var reset_color_code = "\033[0m";

			var output = [];

			output.push([proc_bg_color_code, s, ':', process.pid, reset_color_code].join(''));

			output.push([self.channel_tty_colors[channel], channel, reset_color_code].join(''));

			output.push([self.level_tty_colors[level], level, ": ", message, reset_color_code].join(''));
			
			//output.push([].join(''));

			console.log(output.join(' '));
		}
		
		var stream = self.get_local_log_file();
		
		var d = new Date();
		// TODO use momentjs
		var d_str = ['[', d.getFullYear(), '/', ('00' + (d.getMonth()+1)).slice(-2), '/', ('00' + d.getDate()).slice(-2), ' ', ('00' + d.getHours()).slice(-2), ':', ('00' + d.getMinutes()).slice(-2), ':', ('00' + d.getSeconds()).slice(-2), ']'].join('');

		stream.write([d_str, channel, level, message].join(' '));
		stream.write("\n");

	};

};

exports = module.exports = logger;

