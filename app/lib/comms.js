
var CommsChannel = function(options, grape) {
	var self = this;
	this.self = self;

	this.logger = grape.logger;

	this.pending_callbacks = {};
	this.seq = 0;
	
	this.ipc_message_handlers = {}; 
	this.ipc_messages = {}; 

	this.channels = {};

	this.send = function(cmd, obj, callback) {
		var muid = [process.pid, self.seq].join('-');
		self.seq++;

		var msg = {
			cmd: cmd,
			data: obj,
			muid: muid
		};
		self.pending_callbacks[muid] = callback;
		process.send(msg);
	};

	this.handle_message = function(msg, handle, proc) {
		//self.logger.debug('comms', 'Handling incoming message', JSON.stringify(msg));
		if (msg.cmd)
		{
			var cmd = msg.cmd;
			var reply = false;
			if (cmd.endsWith('Reply'))
			{
				cmd = cmd.substring(0, cmd.length - 'Reply'.length);

				if (!msg.muid)
				{
					self.logger.error('comms', 'Reply message received without a MUID', msg);
				}
				
				if (self.pending_callbacks[msg.muid])
				{
					self.pending_callbacks[msg.muid](msg);
					delete self.pending_callbacks[msg.muid];
				}
				else
				{
					self.logger.error('comms', 'Missing callback for MUID ', msg.muid);
				}
			}
			else if (self.ipc_message_handlers[cmd])
			{
				self.ipc_message_handlers[cmd].handle_message.call(self.ipc_message_handlers[cmd], msg, function(err, data) {
					self.send_reply(err, data, proc, msg);
				}); 
			}
			else
			{
				self.logger.error('comms', 'Unknown handler for message cmd ', msg.cmd);
			}
		}
		else
		{
			self.logger.error('comms', 'Unknown message format (cmd not defined) ', msg);
		}

	};

	this.addHandler = function(handler) {
		// TODO check if already exists
		// TODO check that handler has the correct functions
		if (handler.export_functions)
		{
			Object.keys(handler.export_functions).forEach(function(key) {
				self.ipc_message_handlers[key] = handler;
				self[key] = function() {
					handler.export_functions[key].apply(self, arguments);
				};
			});
		}
	};

	this.send_reply = function(err, data, proc, orig_msg) {
		if (err)
		{
			console.log("ERROR!");
			return;
		}
		
		var msg = {
			cmd: orig_msg.cmd + 'Reply',
			muid: orig_msg.muid,
			data: data
		};

		proc.send(msg);
	};

	this.create_channel = function(channel_name) {
		self.channels[channel_name] = {
			name: channel_name,
			subscribers: []
		};
	};
	
	this.subscribe_to_channel = function(channel_name, handler) {
		
	};

	this.send_to_channel = function() {
	};
};

module.exports = CommsChannel;

