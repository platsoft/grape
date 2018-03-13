
//Command for handler: 'set'
var IPCMemCache = function(options, grape) {
	var self = this;
	this.self = self;
	this.dataStore = {};

	// message received by master process from child
	this.handle_message = function(msg, callback) {
		if (msg.cmd == 'fetch')
		{
			// TODO put expiry in?
			if (msg.data.k && self.dataStore[msg.data.k])
			{
				callback(null, self.dataStore[msg.data.k], msg);
			}
			else
			{
				callback(null, null, msg);
			}
		}
		else if (msg.cmd == 'set')
		{
			self.dataStore[msg.data.k] = msg.data.v;
			callback(null, msg.data.v, msg);
		}
		else
		{
			callback('Unknown command', null, msg);
		}
	};
	
	// functions to send messages
	this.export_functions = [];
	this.export_functions['fetch'] = function(name, callback) {
		// will be executed in Comms class
		
		this.send('fetch', {k: name}, function(msg) {
			if (msg.error)
				callback(msg.error);
			else
				callback(null, msg.data);
		});
	};
	this.export_functions['set'] = function(name, value, callback) {
		// will be executed in Comms class
		this.send('set', {k: name, v: value}, function(msg) {
			if (callback)
			{
				if (msg.error)
					callback(msg.error);
				else
					callback(null, msg.data);
			}
		});
	};

};


module.exports = IPCMemCache;

