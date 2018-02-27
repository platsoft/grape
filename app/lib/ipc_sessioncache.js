
//Command for handler: ''
var IPCSessionCache = function(options, grape) {
	var self = this;
	this.self = self;
	this.dataStore = {};

	// message received
	this.handle_message = function(msg, callback) {
		if (msg.cmd == 'session_lookup')
		{
			if (msg.data.session_id && self.dataStore[msg.data.session_id])
			{
				callback(null, self.dataStore[msg.data.session_id], msg);
			}
			else
			{
				callback(null, null, msg);
			}
		}
		else if (msg.cmd == 'new_session')
		{
			self.dataStore[msg.data.session_id] = msg.data.data;
			callback(null, msg.data.data, msg);
		}
		else
		{
			callback('Unknown command', null, msg);
		}
	};
	
	this.export_functions = [];
	this.export_functions['session_lookup'] = function(name, callback) {
		// will be executed in Comms class
		
		this.send('session_lookup', {session_id: session_id}, function(msg) {
			if (msg.error)
				callback(msg.error);
			else
				callback(null, msg.data);
		});
	};
	this.export_functions['new_session'] = function(session_id, data, callback) {
		// will be executed in Comms class
		this.send('new_session', {session_id: session_id, data: data}, function(msg) {
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

module.exports = IPCSessionCache;

