/**
 * Grape Database Object
 */

'use strict';
var pg = require('pg');
var util = require('util');
var _ = require('underscore');
var events = require('events');

/**
 * app.get('logger').debug - function(msg)
 * 
 */
function db (_o) {

	events.EventEmitter.call(this);

	/** @type db */
	var self = this;

	var options = {
		dburi: 'postgres@localhost:postgres', 
		debug: false, 
		session_id: null,
		user_id: null,
		timeout: null,
		debug_logger: function(s) { console.log(s); }
	};
	if (typeof _o == 'string')
	{
		_.extend(options, {dburi: _o});
	}
	else
	{
		_.extend(options, _o);
	}

	self.options = options;
	self.client = null;
	self.state = 'close';
	self.last_query_time = null;
	self.query_counter = 0;

	self.connect = function() {
		
		if (self.state == "connecting" || self.state == "open")
		{
			if (self.options.debug)
				self.options.debug_logger("Already open or busy connecting...");
			return;
		}

		if (self.options.debug)
			self.options.debug_logger("Connecting to " + util.inspect(options.dburi) + " for session [" + self.options.session_id + "]");
		self.client = new pg.Client(options.dburi);
		self.state = 'connecting';

		self.client.connect(function(err) {

			if (err != null) 
			{
				self.emit('error', "Could not connect to database " + util.inspect(options.dburi));
				process.exit(5);
			}

			if (self.options.user_id != null)
			{
				self.json_call('grape.set_session_user_id', {user_id: self.options.user_id}, function(err, d) { 
					self.state = 'open';
					self.emit('connected');
				});
				
			}
			else
			{
				self.state = 'open';
				self.emit('connected');
			}

		});

		self.client.on('notice', function(msg) {
			self.emit('notice', msg);

			if (msg.where && msg.where != '')
				msg.where = ' at ' + msg.where;

			var str = ['Notice ', msg.severity, ':', msg.message, msg.where].join(' ');
			if (self.options.debug)
				self.options.debug_logger(str);
		});

		self.client.on('error', function(msg) {
			self.state = 'error';

			if (msg.where && msg.where != '')
				msg.where = ' at ' + msg.where;
			
			self.emit('error', msg);
		});

		self.client.on('end', function() {
			self.state = 'close';
			self.emit('end', {
				session_id: self.options.session_id, 
				user_id: self.options.user_id
			});
		});

	}

	self.connect();

	/*
	 * Checks if connection can be closed.
	 *
	 * Returns true if the following conditions are met:
	 * 	- query_counter = 0
	 * 	- last_query_time is more than timeout milliseconds ago
	 */
	self.checkTimeout = function() {
		if (!self.options.timeout)
			return false;
		if (!self.last_query_time)
			return false;

		var time_since_last_query = (new Date()).getTime() - self.last_query_time.getTime();
		
		// if 5 minutes has passed since the last query has started and there is still pending queries, somethnig went wrong
		if (self.query_counter > 0)
			if (time_since_last_query < (5 * 60 * 1000))
				return false;
			else
				return true; // 5 minutes has passed - kill it

		if (time_since_last_query > self.options.timeout)
			return true;

		return false;
	};

	if (self.options.timeout)
	{
		self.timeoutTimer = setInterval(function() { 
			if (self.checkTimeout() === true)
			{
				console.log("Idle timeout on session [" + self.options.session_id + "]");
				clearInterval(self.timeoutTimer);
				self.client.end();
			}
		}, 5000);
	}

	/**
	 * Short hand function for client.query which also logs query information
	 */
	self.query = function(config, values, callback) {
		if (self.options.debug)
			self.options.debug_logger('Query ' + config + ' ' + values.join(', '));

		self.query_counter++;
		console.log("Query counter [" + self.options.session_id + "]: " + self.query_counter);

		self.last_query_time = new Date();

		var qry = self.client.query(config, values, callback);

		qry.on('error', function(err) { 
			self.emit('error', err);
			self.query_counter--;
			console.log("Query counter [" + self.options.session_id + "]: " + self.query_counter);
		});
		qry.on('end', function(err, result) {
			self.query_counter--;
			console.log("Query counter [" + self.options.session_id + "]: " + self.query_counter);
		});

		return qry;
	};
	
	/**
	 * Calls a db function with one JSON parameter as input, and returning a JSON object
	 *
	 * @param name name of JSON function to call
	 * @param input JSON object
	 * @param callback Callback function taking 2 parameters, error and result. Rows are accessible through result.rows. If it is provided, options.response will be ignored
	 * @param options can contain the following members:
	 * 	response - a node HTTP Response object. If it is provided the out of the function will be send to this HTTP response using res.jsonp
	 *
	 */ 
	self.json_call =  function(name, input, callback, options) {
		options = options || {};
		var alias = name;
		alias = alias.replace(/\./g, '');

		if (!callback && options.response)
		{
			alias = 'r';
			callback = function(err, result) {
				var res = options.response;
				if (err || !result.rows) 
				{
					self.emit('error', err);
					var error_object = {
						'status': 'ERROR',
						'message': err.toString(),
						'code': -99,
						error: err
					};

					res.jsonp(error_object);
					return;
				};
				res.jsonp(result.rows[0][alias]);
				return;
			}
		}

		if (self.options.debug)
			self.options.debug_logger('DB JSON ' + name + ' ' + JSON.stringify(input));

		var result;
		if (options.rows)
			result = self.query("SELECT * FROM " + name + "($1::JSON) AS " + alias, [JSON.stringify(input)], callback);
		else
			result = self.query("SELECT " + name + "($1::JSON) AS " + alias, [JSON.stringify(input)], callback);
		return result;
	};
};
db.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = db;

