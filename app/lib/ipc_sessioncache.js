
//Command for handler: ''
var IPCSessionCache = function(options, grape) {
	var self = this;
	this.self = self;
	this.dataStore = {};

	// message received
	this.handle_message = function(msg, callback) {
		if (msg.cmd == 'session_lookup')
		{
			//console.log("SESSION LOOKUP", msg.data.session_id);
			if (msg.data.session_id && self.dataStore[msg.data.session_id])
			{
				//console.log("REPLYING WITH", self.dataStore[msg.data.session_id]);
				callback(null, self.dataStore[msg.data.session_id], msg);
			}
			else
			{
				//console.log("REPLYING WITH NULL");
				callback(null, null, msg);
			}
		}
		else if (msg.cmd == 'new_session')
		{
			//console.log("STORING SESSION ", msg.data.session_id, "AS", msg.data.data);
			self.dataStore[msg.data.session_id] = msg.data.data;
			callback(null, msg.data.data, msg);
		}
		else
		{
			callback('Unknown command', null, msg);
		}
	};
	
	this.export_functions = [];
	this.export_functions['session_lookup'] = function(session_id, callback) {
		// will be executed in Comms class
		
		//console.log("SENDING session_lookup REQUEST");
		this.send('session_lookup', {session_id: session_id}, function(msg) {
			//console.log("GOT SESSION LOOKUP RESULT", msg);
			if (msg.error)
				callback(msg.error, null);
			else
				callback(null, msg.data);
		});
	};
	this.export_functions['new_session'] = function(session_id, data, callback) {
		//grape.logger.debug('session', "STORING NEW SESSION");
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

