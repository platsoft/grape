var child_process = require('child_process');
var fs = require('fs');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Reports server status',
	db: false
};

// opts will contain: db, argv, base_directory, funcs
GrapeCmd.run = function(opts, cb) {
	
	var running = false;

	var grape_pid = null;

	try {
		var grape_pid = fs.readFileSync(opts.base_directory + '/log/grape.pid');
	} catch (e) {
		//console.log(e);
		running = false;
		grape_pid = null;
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
		process.kill(grape_pid, 'SIGINT');
	}
	else
	{
		opts.funcs.print_warn("Server is not running");
	}

	cb(null);
};

module.exports = GrapeCmd;

