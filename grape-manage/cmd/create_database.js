var child_process = require('child_process');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Recreate the database',
	db: false
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	
	var proc = child_process.spawn(
		'setup_database', 
		['-r', 'config.js'], 
		{shell: true, stdio: 'inherit'}, 
		function(err, stdout, stderr) {
			console.log(stdout);
			cb(null);
		}
	);
};

module.exports = GrapeCmd;

