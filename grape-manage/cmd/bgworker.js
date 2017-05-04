
var child_process = require('child_process');
var commander = require('commander');
var path = require('path');
var bgworker_lib = require(path.resolve(__dirname + '/../../app/lib/ps_bgworker'));
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Commands that interacts with ps_bgworker',
	db: true
};


// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {
	commander
		.option('-s, --status', 'ps_bgworker status')
		.option('-b, --start', 'Start ps_bgworker')
		.option('-k, --stop', 'Stops ps_bgworker')

		.option('-c, --schedule [process_name]', 'Schedules a new process')
		.option('-i, --input [data]', 'Data to send to process')
		.parse(opts.argv);

	if (commander.status)
		GrapeCmd.bgworker_status(opts, cb);
	else if (commander.start)
		GrapeCmd.bgworker_start(opts, cb);
	else if (commander.stop)
		GrapeCmd.bgworker_stop(opts, cb);
	else
	{
		commander.help();
	}

};

GrapeCmd.bgworker_status = function(opts, cb) {

	var ps_bgworker_path = opts.options.ps_bgworker || 'ps_bgworker';

	bgworker_lib.get_bgworker_status(ps_bgworker_path, function(err, obj) {
		if (err)
		{
			cb(err);
			return;
		}

		if (obj.pid == 0)
		{
			opts.funcs.print_warn('ps_bgworker is not running');
			cb(null);
			return;
		}

		opts.funcs.print_ok("ps_bgworker is running with PID " + obj.pid + " and was started using " + obj.cmdline);

		cb(null);
	});
}

GrapeCmd.bgworker_start = function(opts, cb) {
	var ps_bgworker_path = opts.options.ps_bgworker || 'ps_bgworker';
	child_process.exec([ps_bgworker_path].join(' '),
		{
			timeout: 2000,
			encoding: 'utf8'
		},
		function(err, stdout, stderr) {
			if (err && !stdout)
			{
				cb(err);
			}
			else
			{
				opts.funcs.print_ok("ps_bgworker started: " + stdout);
				cb(null);
			}

		}
	);
}

GrapeCmd.bgworker_stop = function(opts, cb) {
	var ps_bgworker_path = opts.options.ps_bgworker || 'ps_bgworker';
	bgworker_lib.get_bgworker_status(ps_bgworker_path, function(err, obj) {
		if (err)
		{
			cb(err);
			return;
		}
		process.kill(obj.pid);
		opts.funcs.print_ok("ps_bgworker with PID " + obj.pid + " stopped");
		cb(null);
	});

}


module.exports = GrapeCmd;

