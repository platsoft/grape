/**
 * Classes for creating 2-way communiction between a master process and workers
 */

var net = require('net');
var fs = require('fs');
var events = require('events');
var gutil = require('./util.js');

var MessageSocket = function (socket) {
	this.socket = socket;
	this._headbuffer = null;
	this._buffer = null;
	// how much has been read
	this._read_len = -1;
	var self = this;

	// payload length
	this._msg_len = -1;

	socket.on('data', function(buf) { self.processData(buf); });
};

MessageSocket.prototype.processData = function(_buf) {
	//console.log("PROCESSING: " );
	//console.log(_buf);
	var buf = _buf;
	//new message, all buffers are empty
	if (this._headbuffer == null)
	{
		//create the headbuffer
		this._headbuffer = new Buffer(13);
		if (buf.length >= 13)
		{
			buf.copy(this._headbuffer, 0, 0, 13); 
		}
		buf = buf.slice(13);
	}

	if (this._msg_len < 0 && this._headbuffer != null)
	{
		this._msg_len = this._headbuffer.readUInt32BE(9);
		this._read_len = 0;
	}

	//console.log("Preparing to get new message of length " + this._msg_len);
	if (this._buffer == null && this._msg_len >= 0)
	{
		this._buffer = new Buffer(this._msg_len);
	}

	// how much data is missing from this message
	var left = this._msg_len - this._read_len;

	// if it is more than what we got
	if (left >= buf.length)
	{
		buf.copy(this._buffer, this._read_len, 0, buf.length);
		this._read_len = this._read_len + buf.length;
		buf = buf.slice(buf.length);
	}
	else //we got more than what we need, so the buffer probably contains the next message as well
	{
		buf.copy(this._buffer, this._read_len, 0, left);
		this._read_len = this._read_len + left;
		buf = buf.slice(left);
	}

	if (this._read_len == this._msg_len)
	{
		var message = gutil.decodeMessage(Buffer.concat([this._headbuffer, this._buffer]));
		this.emit('message', message);
		this._headbuffer = null;
		this._buffer = null;
		this._msg_len = -1;
		this._read_len = -1;

		if (buf.length > 0)
			this.processData(buf);
	}
};

MessageSocket.prototype.__proto__ = events.EventEmitter.prototype;


var ServerFIFO = function (_opt) { 
	this.self = this;
	var self = this;
	this.options = require(__dirname + '/options.js')(_opt);
	this.dataStore = {};

	this.start = function() {
		this.fifo = this.options.log_directory + '/grape.fifo';

		console.log("Setting up FIFO ", this.fifo, " for cache comms");

		var server = net.createServer();

		process.on('exit', function(code) {
			if (fs.existsSync(self.fifo))
				fs.unlinkSync(self.fifo);
		});

		server.on('error', function(err) { 
			if (err.code == 'EADDRINUSE')
			{
				console.log("Pipe ", self.fifo, "already exists. This is probably due to an unclean shutdown. If this is the case, please remove the file manually");
			}
			else
			{
				console.log(err);
				console.log("Error creating pipe ", self.fifo, ". Error code: ", err.code);
			}
			this.emit('error', err);
		});

		server.listen(this.fifo, function() {});

		server.on('connection', function(socket) {
			var ms = new MessageSocket(socket);
			ms.on('message', function(message) {
				//console.log("SERVER RECEIVED ON PIPE: ");
				//console.log(message);

				switch (message.command)
				{
					//get value
					case 1:
						var data = {'k': message.data.k, 'v': self.dataStore[message.data.k]};
						var message = gutil.encodeMessage(message.muid, 1, data);
						
						break;
					// set value
					case 2:
						if (typeof message.data.v == 'undefined' || !message.data.v)
						{
							delete self.dataStore[message.data.k];
							var data = {'k': message.data.k};
						}
						else
						{
							self.dataStore[message.data.k] = message.data.v;
							var data = {'k': message.data.k, 'v': message.data.v};
						}
						var message = gutil.encodeMessage(message.muid, 2, data);
						break;
				}
				this.socket.write(message);
			});
		});
	};
};

var WorkerFIFO = function (_opt) { 
	this.self = this;
	var self  = this;
	this.options = require(__dirname + '/options.js')(_opt);
	this.socket = null;
	this.callbacks = [];
	this.seq = 0;

	this.start = function() {
		this.fifo = this.options.log_directory + '/grape.fifo';
		this.socket = net.connect({path: this.fifo});

		this.socket.on('error', function(e) {
			console.log("Error connecting to socket", e);
			
		});

		this.socket.on('connect', function() {
			var ms = new MessageSocket(self.socket);
			ms.on('message', function(message) {
				//console.log("CLIENT RECEIVED ON PIPE: " );
				//console.log(message);
				if (message.command == 1)
				{
					var callback = self.callbacks[message.muid];
			
					callback(message.data);
				}
			});
		});
	};

	/**
 	 *  Try to fetch a variable from the cache
	 */ 
	this.fetch = function(varname, callback) {
		this.send_command(1, {'k': varname}, callback);
	};

	this.set = function(varname, val, callback) {
		this.send_command(2, {'k': varname, 'v': val}, callback);
	};

	this.send_command = function(command, data, callback) {
		this.seq++;
		var muid = process.pid + this.seq;
		self.callbacks[muid] = callback;
		var message = gutil.encodeMessage(muid, command, data);
		this.socket.write(message);
	};

};


ServerFIFO.prototype.__proto__ = events.EventEmitter.prototype;
WorkerFIFO.prototype.__proto__ = events.EventEmitter.prototype;

exports = module.exports = { server: ServerFIFO, worker: WorkerFIFO };

