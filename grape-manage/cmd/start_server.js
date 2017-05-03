var child_process = require('child_process');
var fs = require('fs');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Start server',
	db: false
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	
	var stdout = fs.openSync('./log/run.log', 'a');
	var stderr = fs.openSync('./log/run.log', 'a');

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
	
	cb(null);
};

module.exports = GrapeCmd;

