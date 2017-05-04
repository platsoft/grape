var child_process = require('child_process');
var fs = require('fs');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Start server',
	db: false
};

// opts will contain: db, argv, base_directory, funcs
GrapeCmd.run = function(opts, cb) {
	
	var running = false;
	try {
		var grape_pid = fs.readFileSync(opts.base_directory + '/log/grape.pid');

		process.kill(grape_pid, 0);
		
		running = true;

	} catch (e) {
		running = false;
	};

	if (running == false)
	{
		var stdout = fs.openSync(opts.base_directory + '/log/run.log', 'a');
		var stderr = fs.openSync(opts.base_directory + '/log/run.log', 'a');

		var proc = child_process.spawn(
			'node', 
			['index.js'], 
			{
				shell: true, 
				detached: true,
				stdio: ['ignore', stdout, stderr]
			}
		);
		
		proc.unref();

		opts.funcs.print_ok("Server started (PID " + proc.pid + ")");
	}
	else
	{
		opts.funcs.print_error("Server is already running (PID " + grape_pid + ")");
	}	
		cb(null);
};

module.exports = GrapeCmd;

