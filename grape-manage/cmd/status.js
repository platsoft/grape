var child_process = require('child_process');
var fs = require('fs');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Reports server status',
	db: false
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	
	var running = false;

	try {
		var grape_pid = fs.readFileSync(opts.base_directory + '/log/grape.pid');
	} catch (e) {
		opts.funcs.print_warn("Server is not running (log/grape.pid does not exist)");
		cb(null);
	};
	try {
		process.kill(grape_pid, 0);
		running = true;
	} catch (e) {
		running = false;
	}

	if (running === true)
	{
		opts.funcs.print_ok("Server is running with PID " + grape_pid);
	}
	else
	{
		opts.funcs.print_warn("Server is not running");
	}

	cb(null);
};

module.exports = GrapeCmd;

