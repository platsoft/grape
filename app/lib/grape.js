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
var ldap_server = require(__dirname + '/ldap.js').LDAPServer;
var async = require('async');
var events = require('events');

function grape(_o) {
	this.self = this;
	var self  = this;
	this.options = require(__dirname + '/options.js')(_o);

	this.start = function() {

		// Check options
		if (!this.options.base_directory)
		{
			console.log("Error: I could not find a base directory. Specify it with the 'base_directory' option in config.js");
			process.exit(1);
		}

		if (cluster.isMaster)
		{
			var pidfile = this.options.log_directory + '/grape.pid';

			if (this.options.process_name)
				process.title = this.options.process_name;

			// check if pidfile exists, if it does kill the process and delte the file
			var start_pidfile = function(next) {
				self.emit('start_pidfile');

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
				
				self.emit('start_pidfile_done');
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

				if (self.options.enable_ldap_server == true)
				{
					self.createLDAPServer();
				}

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
					process.exit(1);
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
				if (this.options.process_name)
					process.title = [this.options.process_name, 'apiserver'].join('-');
				// We are a worker/child process
				var app = new g_app(_o);

				var cache = new comms.worker(_o);
				cache.start();
				app.express.set('cache', cache);
				
				self.emit('instance', app);
			}
			else if (process.env.state && process.env.state == 'db_notification_listener')
			{
				if (this.options.process_name)
					process.title = [this.options.process_name, 'dbnotify'].join('-');

				var e_notify = new email_notification_listener(_o);
				e_notify.start();

				// Other db notification functions can go here
			}
			else if (process.env.state && process.env.state == 'ldap_server')
			{
				if (this.options.process_name)
					process.title = [this.options.process_name, 'ldapserver'].join('-');

				var e_ldap = new ldap_server(self.options);
				e_ldap.start();

				// Other db notification functions can go here
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
				self.createDBNotificationListener();
			}
		});
		worker.on('death', function() {
			console.log("DB Notify Worker died");
			self.createDBNotificationListener();
		});

	};

	this.createLDAPServer = function() {
		console.log("Starting LDAP server");
		var worker = cluster.fork({"state": "ldap_server"});
		worker.on('disconnect', function() {
		});
		worker.on('exit', function() {
			console.log("LDAP server exit with code", worker.process.exitCode);
			if (worker.process.exitCode == 5)
			{
				console.log("Connectivity issue. Restarting in 5 seconds...");
				setTimeout(function() { self.createLDAPServer(); }, 5000);
			}
			else
			{
				self.createLDAPServer();
			}
		});
		worker.on('death', function() {
			console.log("DB Notify Worker died");
			self.createLDAPServer();
		});

	};

};


grape.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = grape;


