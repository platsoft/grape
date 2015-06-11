/**
 * Grape Database Object
 * @typedef {object} db
 * @property {object} client - A open instance of pgClient.
 * @property {function} query - a short hand function to query data.  
 * @property {object} models - Dynamicly generated models as specified in the `models` variable.
 * @property {object} collections - Dynamicly generated collactions for the models.
 */
'use strict';
var pg = require('pg');
var util = require('util');
var _ = require('underscore');
var events = require('events');

/**
 * Database singleton, allowing us to only have one db object and share that between
 * all the modules that requires this module.
 * 
 * @todo This might not be needed due to the fact that nodejs share the require modules. 
 * But it needs to get checked. Better save then sorry.
 * 
 * @param app {object} The app initializer normally a Express Application instance using
 * the following getters:
 * 
 * app.get('logger').error - function(msg) 
 * app.get('logger').debug - function(msg)
 * app.get('dburi') - string
 * 
 * If you supply the above attributes in a dummy object you can easily unit test
 * this module.
 */
function db (_o) {

	events.EventEmitter.call(this);

	/** @type db */
	var self = this;

	var options = {
		dburi: 'postgres@localhost:postgres', 
		debug: false, 
		debug_logger: function(s) { console.log(s); }, 
		error_logger: function(s) { console.log(s); },
		connected_callback: function() { }
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

	self.options.debug_logger("Connecting to " + util.inspect(options.dburi));
	self.client = new pg.Client(options.dburi);
	self.client.connect(function(err) {
		if (err != null) 
		{
			self.options.error_logger("Could not connect to database", options.dburi);
			process.exit(5);
		};
		if (self.options.connected_callback) 
		{
			self.options.connected_callback(self);
		}
		self.emit('connected');
	});

	self.client.on('notice', function(msg) {
		self.emit('notice', msg);

		if (msg.where && msg.where != '')
			msg.where = ' at ' + msg.where;

		var str = ['Notice ', msg.severity, ':', msg.message, msg.where].join(' ');
		self.options.debug_logger(str);
	});
	self.client.on('error', function(msg) {
		console.log("ERRRRRRRROR", msg);
		self.emit('error', msg);

		if (msg.where && msg.where != '')
			msg.where = ' at ' + msg.where;

		var str = ['DB Error', msg.severity, ':', msg.message, msg.where].join(' ');
		self.options.error_logger(str);
	});



	/**
	 * Short hand function for client.query which also logs query information
	 * 
	 * @deprecated - Used by backbone generate models or old(but in use) API modules
	 */
	self.query = function(config, values, callback) {
		if (self.options.debug)
		{
			self.options.debug_logger('Query ' + config + ' ' + values.join(', '));
		}

		var qry = self.client.query(config, values, callback);
		qry.on('error', function(err) { 
			self.emit('error', err);
			self.options.error_logger('DB Error ' + err.toString());
		});
		return qry;
	};
	
	/**
	 * call db function name with input json and return json 
	 * options.response - httpresponse object, json sent there
	 *
	 */ 
	self.jsonCall =  function(name, input, callback, options) {
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
					self.options.error_logger(util.inspect(err));
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

		self.options.debug_logger('DB JSON ' + name + ' ' + JSON.stringify(input));
		var result;
		if (options.rows)
			result = self.query("SELECT * FROM " + name + "($1::JSON) AS " + alias, [JSON.stringify(input)], callback);
		else
			result = self.query("SELECT " + name + "($1::JSON) AS " + alias, [JSON.stringify(input)], callback);
		return result;
	};
	self.json_call = self.jsonCall;
};
db.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = db;

