
var _ = require('underscore');
var fs = require('fs');
var util = require('util');
var cluster = require('cluster');
var g_app = require(__dirname + '/app.js');

exports = module.exports = function(_o) {
	this.self = this;
	var self  = this;
	this.options = require(__dirname + '/options.js')(_o);

	this.start = function() {
		if (cluster.isMaster)
		{
			var pidfile = this.options.log_directory + '/grape.pid';

			var start_instances = function() {
				fs.writeFileSync(pidfile, process.pid.toString());

				process.on('exit', function(code) {
					fs.unlinkSync(pidfile);
				});
				process.on('SIGINT', function(code) {
					console.log("Caught SIGINT, exiting gracefully");
					process.exit(1);
				});

				console.log("Starting " + self.options.instances + " instances");
				for (var i = 0; i < self.options.instances; i++)
				{
					self.createWorker();
				}
			};

			if (fs.existsSync(pidfile))
			{
				//check if process exists
				var old_pid = fs.readFileSync(pidfile, 'UTF8');
				if (process.kill(old_pid, 0))
				{
					process.kill(old_pid, 'SIGINT');
					setTimeout(start_instances, 2000);
				}
				else
				{
					start_instances();
				}
			}
			else
			{
				start_instances();
			}
		}
		else
		{
			var app = g_app(_o);
		}
	};

	this.createWorker = function()
	{
		var worker = cluster.fork();
		worker.on('disconnect', function() {
		});
		worker.on('exit', function() {
			self.createWorker();
		});
	};
};





