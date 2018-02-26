/**
 * Entry point for a Grape app. This one starts the workers and sets up comms channel between them
 *
 * Events:
 * 	creating_pidfile
 * 	pidfile_created
 *
 */
var _ = require('underscore');
var fs = require('fs');
var util = require('util');
var cluster = require('cluster');
var g_app = require(__dirname + '/http_app.js');
var async = require('async');
var events = require('events');
var configreader = require(__dirname + '/configreader.js');
var grapelib = require(__dirname + '/../index.js');
const path = require('path');
const IPCMemCache = require(__dirname + '/ipc_memcache.js');
const CommsChannel = require(__dirname + '/comms.js');

var email_notification_worker = require(__dirname + '/email_notification_listener.js').EmailNotificationListener;


function grape() {
	this.self = this;
	var self  = this;
	this.options = configreader.apply(null, arguments);
	var logger = new grapelib.logger(this.options);
	this.logger = logger;
		
	var comms = new CommsChannel(self.options, self);
	this.comms = comms;

	this.workers = [];

	this.state = 'init';

	this.setup = function() {
		self.addWorker({
			name: 'httplistener',
			instance_count: self.options.instances || 5,
			func: g_app
		});

		// TODO emailer must not be here
		self.addWorker({
			name: 'emailer',
			instance_count: 1,
			func: email_notification_worker
		});

		// TODO add custom handlers 
		var ipcmemcache = new IPCMemCache(self.options, self);
		
		self.comms.addHandler('set', ipcmemcache);
		self.comms.addHandler('fetch', ipcmemcache);

		process.on('message', function(msg, handle) {
			self.comms.handle_message(msg, handle, process);
		});

	};

	this.addWorker = function(obj) {
		if (cluster.isMaster || process.env.state == obj.name)
		{
			if (!obj.name)
			{
				self.logger.error('app', 'Missing name for worker object ', obj.name); // TODO add some more info?
				return;
			}

			self.workers.push({
				name: obj.name,
				instance_count: obj.instance_count || 1,
				processes: [],
				func: obj.func
			});
		}
	};

	this.start = function() {

		// Check options
		if (!this.options.base_directory)
		{
			self.logger.error('app', 'Missing base_directory ', obj.name); // TODO add some more info?
			console.log("Error: I could not find a base directory. Specify it with the 'base_directory' option in your configuration");
			process.exit(1);
		}

		if (cluster.isMaster)
		{
			logger.debug('app', 'Starting application with the following options: ' + util.inspect(this.options));

			var pidfile = path.join(this.options.log_directory, '/grape.pid');

			if (this.options.process_name)
				process.title = this.options.process_name;

			// check if pidfile exists, if it does kill the process and delte the file
			var create_pidfile = function(next) {
				self.emit('creating_pidfile');

				self.logger.debug('app', 'Setting up PID file ', pidfile, ' ...');
				if (fs.existsSync(pidfile))
				{
					self.logger.debug('app', 'PID file already exists');
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
						self.logger.debug('app', 'Overwriting PID file');
						fs.writeFileSync(pidfile, process.pid.toString());
						next();
					}
				}
				else
				{
					fs.writeFileSync(pidfile, process.pid.toString());
					next();
				}
				
				self.emit('pidfile_created');
			}

			//start worker instances
			var start_workers = function(next) {

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
				
				for (var i = 0; i < self.workers.length; i++)
				{
					var worker = self.workers[i];
					for (var j = 0; j < worker.instance_count; j++)
					{
						self.forkWorker(worker, j);
					}
				}

				next();
			};

			async.series([create_pidfile, start_workers]);
		}
		else  // we are the child/worker process
		{
			if (process.env.state)
			{
				var instance_count = process.env.instance_count || '0';

				logger.info('app', process.env.state,  '#' + instance_count, 'process pid', process.pid, 'started');
				var process_name = self.options.process_name || 'grape-unknown';

				var found = false;
				for (var i = 0; i < self.workers.length && !found; i++)
				{
					if (self.workers[i].name == process.env.state)
					{

						found = true;
						process.title = [process_name, '-', self.workers[i].name, '[', instance_count , ']'].join('');
						var obj = new (self.workers[i].func)(self.options, self);
						
						//self.emit(['worker', self.workers[i].name, 'created'].join('-'), obj);

						if (obj.start)
							obj.start.call(obj);

						self.emit('worker', self.workers[i], obj);
						self.emit(['worker-', self.workers[i].name].join(''), self.workers[i], obj);
					}
				}

				if (!found)
				{
					console.log("UNKNOWN WORKER " + process.env.state);
				}
			}
		}
	};

	this.forkWorker = function(worker, instance_idx) {
		self.logger.info("app", "Starting worker: " + worker.name);
		var new_process = cluster.fork({"state": worker.name, "instance_count": instance_idx});
		new_process.on('disconnect', function() {
		});
		new_process.on('exit', function() {
			console.log(worker.name + "[" + instance_idx + "]: Worker process exited with code", new_process.process.exitCode);
			if (new_process.process.exitCode == 5)
			{
				console.log("Connectivity issue. Restarting in 5 seconds...");
				setTimeout(function() { 
					self.forkWorker(worker, instance_idx); 
				}, 5000);
			}
			else
			{
				self.forkWorker(worker, instance_idx);
			}
		});
		new_process.on('death', function() {
			self.logger.error('app', "Worker died"); // TODO add some more info?
			self.forkWorker(worker, instance_idx);
		});
		new_process.on('message', function(msg, handle) {
			self.logger.debug('comms', 'Received a message from PID', new_process.process.pid);
			self.comms.handle_message(msg, handle, new_process);
		});
	};

	this.setup();
};


grape.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = grape;


