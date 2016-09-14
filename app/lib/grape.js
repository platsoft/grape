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
var email_notification_listener = require(__dirname + '/email_notification_listener.js').EmailNotificationListener;
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

				self.createDBNotificationListener();

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
					console.log("Comms channel error", message);
				});
				channel.start();
				next();
			};


			async.series([start_pidfile, start_comms_channel, start_instances]);
		}
		else
		{
			if (process.env.state && process.env.state == 'api_listener_worker')
			{
				// We are a worker/child process
				var app = g_app(_o);
				var cache = new comms.worker(_o);
				cache.start();
				app.set('cache', cache);
			}
			else if (process.env.state && process.env.state == 'db_notification_listener')
			{
				var e_notify = new email_notification_listener(_o);
				e_notify.start();
			}
			else
			{
				console.log("UNKNOWN WORKER");
			}
		}
	};

	this.createWorker = function()
	{
		var worker = cluster.fork({"state": "api_listener_worker"});
		worker.on('disconnect', function() {
		});
		worker.on('exit', function() {
			console.log("Worker exit with code", worker.process.exitCode);
			if (worker.process.exitCode == 5)
			{
				console.log("Connectivity issue. Restarting in 5 seconds...");
				setTimeout(function() { self.createWorker(); }, 5000);
			}
			else
			{
				self.createWorker();
			}
		});
		worker.on('death', function() {
			console.log("Worker died");
			self.createWorker();
		});

	};

	this.createDBNotificationListener = function() {
		console.log("Starting DB notification listener");
		var worker = cluster.fork({"state": "db_notification_listener"});
		worker.on('disconnect', function() {
		});
		worker.on('exit', function() {
			console.log("DB Notify Worker exit with code", worker.process.exitCode);
			if (worker.process.exitCode == 5)
			{
				console.log("Connectivity issue. Restarting in 5 seconds...");
				setTimeout(function() { self.createDBNotificationListener(); }, 5000);
			}
			else
			{
				self.createWorker();
			}
		});
		worker.on('death', function() {
			console.log("DB Notify Worker died");
			self.createDBNotificationListener();
		});

	};
};





