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

	var self = this;

	var options = {
		dburi: 'postgres@localhost:postgres', 
		debug: false, 
		session_id: null,
		username: null,
		db_idle_timeout: null
	};
	if (typeof _o == 'string')
	{
		_.extend(options, {dburi: _o});
	}
	else
	{
		_.extend(options, _o);
	}

	this.options = options;
	this.client = null;
	this.state = 'close';
	this.last_query_time = null;
	this.query_counter = 0;

	this.notification_callbacks = {};
	this.notification_listener = false;
	this.installed_channels = [];
	this.pending_channels = [];

	this.connect = function() {

		if (self.no_reconnect)
		{
			// refusing to connect if no_reconnect is set
			return;
		}
		
		if (self.state == "connecting" || self.state == "open")
		{
			if (self.options.debug)
				self.emit('debug', "Connect function called but I am already open or busy connecting...");
			return;
		}

		if (self.options.debug)
			self.emit('debug', "Connecting to " + util.inspect(options.dburi) + " for session [" + self.options.session_id + "]");
		self.client = new pg.Client(options.dburi);
		self.state = 'connecting';

		self.client.connect(function(err) {

			if (err != null) 
			{
				self.emit('error', "Could not connect to database " + util.inspect(options.dburi));
				process.exit(5);
			}

			if (self.options.session_id != null)
			{
				self.json_call('grape.set_session', {session_id: self.options.session_id}, function(err, d) { 
					self.state = 'open';
					self.emit('connected');
				});
				
			}
			else
			{
				self.state = 'open';
				self.emit('connected');
				self.setup_notification_listener();
			}

		});

		self.client.on('notice', function(msg) {
			self.emit('notice', msg);

			if (msg.where && msg.where != '')
				msg.where = ' at ' + msg.where;

			var str = ['Notice ', msg.severity, ':', msg.message].join(' ');
			if (self.options.debug)
				self.emit('debug', str); 
		});

		self.client.on('error', function(msg) {
			self.state = 'error';

			self.query_counter--;
			if (self.options.debug)
			{
				self.emit('debug', "Database error [" + self.options.session_id + "]:" + util.inspect(msg));
				self.emit('debug', "Query counter DBERR [" + self.options.session_id + "]: " + self.query_counter);
			}


			if (msg.where && msg.where != '')
				msg.where = ' at ' + msg.where;

			self.emit('error', msg);

			if (msg.code == '57P01')
			{
				self.client.end();
			}
		});

		self.client.on('end', function() {
			self.state = 'close';
			self.emit('end', {
				session_id: self.options.session_id
			});

			if (self.options.debug)
			{
				self.emit('debug', "Database end [" + self.options.session_id + "]");
			}

		});

	}

	this.connect();

	this.disconnect = function(no_reconnect, cb) {
		if (no_reconnect)
			self.no_reconnect = no_reconnect;
		if (self.state == 'closing' || self.state == 'close')
		{
			if (cb)
				cb();
			return; //already closed
		}
		
		self.state = 'closing';
		self.client.end(cb);
	};

	/*
	 * Checks if connection can be closed.
	 *
	 * Returns true if the following conditions are met:
	 * 	- query_counter = 0
	 * 	- last_query_time is more than timeout milliseconds ago
	 */
	this.checkTimeout = function() {
		if (!self.options.db_idle_timeout)
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

		if (time_since_last_query > self.options.db_idle_timeout)
			return true;

		return false;
	};

	if (this.options.db_idle_timeout)
	{
		this.timeoutTimer = setInterval(function() { 
			if (self.checkTimeout() === true)
			{
				if (self.options.debug)
					self.emit('debug', "Idle timeout on session [" + self.options.username + "][" + self.options.session_id + "]");

				clearInterval(self.timeoutTimer);
				self.client.end();
			}
		}, 5000);
	}

	/**
	 * Short hand function for client.query which also logs query information
	 */
	this.query = function(qry_text, values, callback, qry_options) {
		if (!values)
			var values = [];
		if (!qry_options)
			var qry_options = {log: true};

		self.query_counter++;
		if (self.options.debug && qry_options.log === true)
		{
			self.emit('debug', 'New query for [' + (self.options.username || '') + ':' + self.options.session_id + '] ' + qry_text + '; ' + values.join(', '));
			if (self.query_counter > 3)
			{
				self.emit('debug', 'This database connection currently has ' + self.query_counter + ' pending database queries');
			}
		}

		self.last_query_time = new Date();

		var qry = self.client.query(new pg.Query(qry_text, values));

		if (callback && typeof callback == 'function')
		{
			qry.on('row', function(row, result) {
				result.addRow(row);
			});

			qry.on('error', function(err) { 
				self.emit('error', err);
				self.query_counter--;
				if (self.options.debug && self.query_counter > 0)
					self.emit('debug', "Number of outstanding DB queries for [" + self.options.session_id + "]: " + self.query_counter);

				callback(err, null);
			});

			qry.on('end', function(result) {
				self.query_counter--;
				if (self.options.debug && self.query_counter > 0)
					self.emit('debug', "Number of outstanding DB queries for [" + self.options.session_id + "]: " + self.query_counter);
				
				callback(null, result);
			});
		}

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
	 * 	rows - if true the query will expect a SETOF return
	 *
	 */ 
	this.json_call =  function(name, input, _callback, qry_options) {
		var callback = _callback;
		qry_options = qry_options || { rows: false, single: false, jsonb: false };
		
		if (_callback && typeof _callback == 'object')
		{
			_.extend(qry_options, _callback);
			callback = null;
		}

		var alias = name;
		if (qry_options.alias)
			alias = qry_options.alias;
		
		alias = alias.replace(/\./g, '');

		// response is the express response object to return the result to
		if (!callback && qry_options.response)
		{
			alias = 'r';
			callback = function(err, result) {
				var res = qry_options.response;
				if (err || !result.rows) 
				{
					self.emit('error', err);
					var error_object = {
						'status': 'ERROR',
						'message': err.toString(),
						'code': -99,
						'error': err
					};

					res.jsonp(error_object);
					return;
				};
				res.jsonp(result.rows[0][alias]);
				if (self.options.debug)
					self.emit('debug', 'Database response: ' + JSON.stringify(result.rows[0][alias]));
				return;
			}
		}

		if (self.options.debug)
		{
			self.emit('debug', '[' + self.options.username + '][' + self.options.session_id + ']' + ' SELECT ' + name + " ('" + JSON.stringify(input) + "'::JSON) AS " + alias);
		}

		var _type = 'JSON';
		if (qry_options.jsonb && qry_options.jsonb === true)
			_type = 'JSONB';


		var qry;
		if (qry_options.rows)
			qry = self.query(["SELECT * FROM ", name, "($1::", _type, ") AS ", alias].join(''), [JSON.stringify(input)], callback, {log:false});
		else
			qry = self.query(["SELECT ", name, "($1::", _type, ") AS ", alias].join(''), [JSON.stringify(input)], callback, {log:false});

		return qry;
	};
	
	this.jsonb_call =  function(name, input, _callback, qry_options) {
		return self.json_call(name, input, _callback, _.extend(qry_options || {}, {jsonb: true}));
	};

	this.setup_notification_listener = function() {

		if (self.state != 'open')
			return;  // will have to wait for later

		//only do it the first time
		if (self.notification_listener == false)
		{
			self.client.on('notification', function(msg) {
				var available = Object.keys(self.notification_callbacks);
				if (available.indexOf(msg.channel) >= 0)
				{
					try {
						(self.notification_callbacks[msg.channel])(msg.payload);
					} catch (e) { }
				}
			});

			self.notification_listener = true;
		}
		
		if (self.pending_channels.length > 0)
		{
			self.pending_channels.forEach(function(channel) {
				self.client.query("LISTEN " + channel);
			});
			self.installed_channels = self.installed_channels.concat(self.pending_channels);
			self.pending_channels = [];
		}

	};

	this.new_notify_handler = function(channel, handler) {
		self.notification_callbacks[channel] = handler;
		self.pending_channels.push(channel);
		this.setup_notification_listener();
	};
};
db.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = db;

