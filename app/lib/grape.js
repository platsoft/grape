/**
 * Entry point for a Grape app. This one starts the workers and sets up comms channel between them
 *
 */
var _ = require('underscore');
var fs = require('fs');
var util = require('util');
var cluster = require('cluster');
var g_app = require(__dirname + '/app.js');
var comms = require(__dirname + '/comms.js');
var async = require('async');

exports = module.exports = function(_o) {
	this.self = this;
	var self  = this;
	this.options = require(__dirname + '/options.js')(_o);

	this.start = function() {
		if (cluster.isMaster)
		{
			var pidfile = this.options.log_directory + '/grape.pid';

			// check if pidfile exists, if it does kill the process and delte the file
			var start_pidfile = function(next) {
				console.log("Setting up PID file " + pidfile + " ...");
				if (fs.existsSync(pidfile))
				{
					console.log("PID file exists");
					//check if process exists
					var old_pid = fs.readFileSync(pidfile, 'UTF8');
					var proc_running = false;
					try {
						proc_running = process.kill(old_pid, 0);
					} catch (e) {
						proc_running = false;
					}
					if (proc_running)
					{
						console.log("Killing running process " + old_pid + " (found from pidfile)");
						process.kill(old_pid, 'SIGINT');
						setTimeout(function() { 
							fs.writeFileSync(pidfile, process.pid.toString());
							next(); 
						}, 2000);
					}
					else
					{
						console.log("Overwriting PID file ");
						fs.writeFileSync(pidfile, process.pid.toString());
						next();
					}
				}
				else
				{
					console.log("PID does not exist");
					fs.writeFileSync(pidfile, process.pid.toString());
					next();
				}

			}

			//start worker instances
			var start_instances = function(next) {

				process.on('exit', function(code) {
					console.log("Process exiting ");
					fs.unlinkSync(pidfile);
				});
				process.on('SIGINT', function(code) {
					console.log("Caught SIGINT, exiting gracefully");
					process.exit(1);
				});
				process.on('SIGUSR2', function(code) {
					console.log("Caught SIGUSR2, exiting gracefully");
					process.exit(1);
				});


				console.log("Starting " + self.options.instances + " instances");
				for (var i = 0; i < self.options.instances; i++)
				{
					self.createWorker();
				}

				next();
			};


			var start_comms_channel = function(next) {
				var channel = new comms.server(_o);
				channel.on('error', function(message) {
					//TODO
				});
				channel.start();
				next();
			};

			async.series([start_pidfile, start_comms_channel, start_instances]);
		}
		else
		{
			var app = g_app(_o);
			var cache = new comms.worker(_o);
			cache.start();
			app.set('cache', cache);
		}
	};

	this.createWorker = function()
	{
		var worker = cluster.fork();
		worker.on('disconnect', function() {
		});
		worker.on('exit', function() {
			console.log("Worker exit");
			self.createWorker();
		});
		worker.on('death', function() {
			console.log("Worker died");
			self.createWorker();
		});

	};
};





