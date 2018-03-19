'use strict';

var events = require('events');
var http = require('http');
var https = require('https');
var url = require('url');
var util = require('util');
var fs = require('fs');
var querystring = require('querystring');
var _path = require('path');

var use_http = null;

/**
 * @event login Emitted after successful login attempt
 * @event logout Emitted after logout
 *
 */
var GrapeClient = function(_o) {
	events.EventEmitter.call(this);

	this.protocol = 'http:';
	this.session = null;
	this.url = '';
	this.hostname = 'localhost';
	this.port = 3001;
	this.username = null;
	this.password = null;
	this.auth = null;
	this.default_path = null;
	this.get_notifications = false;
	var self = this;
	this.self = self;

	this.parsedURL = {};

	if (_o.url)
	{
		this.url = _o.url;
		var urlObj = url.parse(this.url);
		this.hostname = urlObj.hostname;
		this.port = urlObj.port;
	
		if (urlObj.auth)
		{
			var ar = urlObj.auth.split(':');
			this.username = ar[0];
			if (ar.length > 1)
				this.password = ar[1];
		}

		this.parsedURL = urlObj;

		if (urlObj.auth)
			this.auth = urlObj.auth;
		if (urlObj.path)
			this.default_path = urlObj.path;
		this.protocol = urlObj.protocol;

		if (this.protocol == 'http:')
			use_http = http;
		else if (this.protocol == 'https:')
		{
			process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
			use_http = https;
		}

	}


	if (_o.username)
		this.username = _o.username;
	if (_o.password)
		this.password = _o.password;

	this.postJSON = function(path, obj, cb) {
		if (path == null)
			var path = this.default_path;

		var data = JSON.stringify(obj);

		if (this.session)
			var session_id = this.session.session_id;
		else
			var session_id = '';

		var options = {
			hostname: this.hostname,
			port: this.port,
			method: 'POST',
			path: path,
			headers: {
				'Accept': 'application/json',
				'Content-Type': 'application/json',
				'Content-Length': Buffer.byteLength(data)
			}
		};

		if (this.auth)
		{
			options.headers['Authorization'] = 'Basic ' + (new Buffer(this.auth).toString('base64'));
		}
		else
		{
			options.headers['X-SessionID'] = session_id;
		}

		var callback = function(res) {
			res.setEncoding('utf8');
			var chunks = [];
			res.on('data', function(chunk) {
				chunks.push(chunk);
			});

			res.on('end', function() {
				var obj = JSON.parse(chunks.join(''));
				cb(obj, res);
			});
		};

		var req = use_http.request(options, callback);
		req.write(data);
		req.end();

		return req;
	};

	this.getJSON = function(path, obj, cb) {
		if (path == null)
			var path = this.default_path;
		var data = querystring.stringify(obj);

		if (this.session)
			var session_id = this.session.session_id;
		else
			var session_id = '';

		var options = {
			hostname: this.hostname,
			port: this.port,
			method: 'GET',
			path: path + '?' + data,
			headers: {
				'Accept': 'application/json'
			}
		};

		if (this.auth)
			options.headers['Authorization'] = 'Basic ' + (new Buffer(this.auth).toString('base64'));
		else
			options.headers['X-SessionID'] = session_id;

		options.headers['X-Notifications'] = 1;

		var callback = function(res) {
			res.setEncoding('utf8');
			var chunks = [];
			res.on('data', function(chunk) {
				chunks.push(chunk);
			});

			res.on('end', function() {
				var obj = JSON.parse(chunks.join(''));
				cb(obj, res);
			});
		};

		var req = use_http.request(options, callback);
		req.end();

		return req;
	};


	this.login = function(username, password, cb) {
		if (username)
			self.username = username;
		if (password)
			self.password = password;

		this.postJSON('/grape/login', {'username': self.username, 'password': self.password}, function(data) {
			if (data.status == 'OK')
			{
				self.session = {
					session_id: data.session_id
				};

			}
			
			if (cb)
			{
				cb(null, data);
			}
			else
			{
				if (data.status == 'OK')
					self.emit('login', data);
				else
					self.emit('error', data);

			}

		}).on('error', function(err) {
			if (cb)
				cb(err, null);
			else
				self.emit('error', err);
		});

	};

	this.logout = function() {
		this.postJSON('/grape/logout', {}, function(data) {
			self.emit('logout');
		});
	};


	/**
	 * path is the API call url
	 * fields is an object containing key/value pairs of field names to send through
	 * files is an object or array of objects with the following fields:
	 * 	file (the path to the file)
	 * 	fieldname (field name)
	 *
	 * */
	this.uploadFile = function(path, fields, files, cb) {
		var _files = [];
		var _fields = [];

		var boundary_string = Math.random().toString(36).substring(10);
		var boundary = '--' + boundary_string;


		var total_size = 0;


		//Files
		function add_file (file)
		{
			var contenttype = file.contenttype || 'application/octet-stream';
			var fieldname = file.fieldname || 'file_name';
			var filename = _path.basename(file.filename || file.file);

			var f = {
				path: file.file,
				filename: filename,
				fieldname: fieldname,
				header: [boundary, "\r\n",
					'Content-Disposition: form-data; name="', fieldname, '"; filename="', filename, '"', "\r\n\r\n"
					].join('')
			};

			var stat = fs.statSync(f.path);
			f.size = stat.size;

			total_size += f.header.length + f.size;

			_files.push(f);
		}

		if (util.isArray(files))
			files.forEach(function(v) {
				add_file(v);
			});
		else
			add_file(files);


		//Fields
		function add_field (field)
		{
			var contenttype = '';
			var data = '';

			if (typeof field.value == 'object')
			{
				contenttype = 'application/json';
				data = JSON.stringify(field.value);
			}
			else
			{
				contenttype = 'plain/text';
				data = field.value;
			}

			var f = [boundary, "\r\n",
					'Content-Disposition: form-data; name="', field.name, '"', "\r\n\r\n",
					data
				].join('');

			total_size += Buffer.byteLength(f);

			_fields.push(f);
		}

		if (util.isArray(fields))
		{
			fields.forEach(function(v) {
				add_field(v);
			});
		}
		else
		{
			var keys = Object.keys(fields);
			keys.forEach(function(k) {
				add_field({name: k, value: fields[k]});
			});
		}



		//Set Session
		if (this.session)
			var session_id = this.session.session_id;
		else
			var session_id = '';

		// Add last boundary entry size
		total_size += boundary.length + 6;

		var options = {
			hostname: this.hostname,
			port: this.port,
			method: 'POST',
			path: path,
			headers: {
				'Accept': 'application/json',
				'Content-Type': 'multipart/form-data; boundary=' + boundary_string,
				'Content-Length': total_size,
				'X-SessionID': session_id
			}
		};

		var callback = function(res) {
			res.setEncoding('utf8');
			var chunks = [];
			res.on('data', function(chunk) {
				chunks.push(chunk);
			});

			res.on('end', function() {
				var obj = JSON.parse(chunks.join(''));
				cb(obj);
			});
		};

		var req = use_http.request(options, callback);



		var pipe_count = 0;

		_files.forEach(function(file) {
			req.write(file.header);

			var readstream = fs.createReadStream(file.path, {});
			readstream.pipe(req, {end: false});

			pipe_count++;

			readstream.on('end', function() {
				req.write("\r\n");
				pipe_count--;
				if (pipe_count <= 0)
				{

					_fields.forEach(function(field) {
						req.write(field);
					});
					req.write("\r\n" + boundary + "--\r\n");
					req.end();
				}
			});
		});
	};
};

GrapeClient.prototype.__proto__ = events.EventEmitter.prototype;

exports = module.exports = GrapeClient;
