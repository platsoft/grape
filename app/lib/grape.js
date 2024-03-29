/**
 * Entry point for a Grape app. This one starts the workers and sets up comms channel between them
 *
 * Events:
 * 	creating_pidfile
 * 	pidfile_created
 *
 */
const _ = require('underscore');
const fs = require('fs');
const util = require('util');
const cluster = require('cluster');
const g_app = require(__dirname + '/http_app.js');
const async = require('async');
const events = require('events');
const configreader = require(__dirname + '/configreader.js');
const grapelib = require(__dirname + '/../index.js');
const path = require('path');
const IPCMemCache = require(__dirname + '/ipc_memcache.js');
const IPCSessionCache = require(__dirname + '/ipc_sessioncache.js');
const CommsChannel = require(__dirname + '/comms.js');
const GrapeSettings = require(path.join(__dirname, 'grape_settings.js'));
const dblib = require(path.join(__dirname, 'db.js'));
const verify_grape_setup = require(path.join(__dirname, 'verify_setup.js'));


function grape() {
	this.self = this;
	var self  = this;
	
	this.options = configreader.apply(null, arguments);

	var logger = new grapelib.logger(this.options);
	this.logger = logger;
	
	var comms = null;
	this.comms = comms;

	this.db = null;

	this.grape_settings = null;

	this.workers = [];

	this.state = 'init';

	this.shutdown_started = 0;

	// only available in workers
	this.current_worker_definition = null;
	this.current_worker = null;

	this.setup = function() {

		if (cluster.isMaster)
		{
			try { 
				fs.unlinkSync(path.join(self.options.log_directory, 'global.log'));
			} catch(e) { 
				// do nothing
			}
		}

		self.addWorker({
			name: 'httplistener',
			instance_count: self.options.http_instance_count || 5,
			func: g_app
		});

	};

	this.setup_comms = function(next) {
		self.comms = new CommsChannel(self.options, self);
		
		self.comms.addHandler(new IPCMemCache(self.options, self));
		self.comms.addHandler(new IPCSessionCache(self.options, self));

		process.on('message', function(msg, handle) {
			self.comms.handle_message(msg, handle, process);
		});
		next();
	};

	this.setup_database = function(next) {

		self.logger.debug('app', 'Attempting database connection...');

		var conn_name = (process.env.state || 'master') + '-' + process.pid;

		var db = new dblib({
			dburi: self.options.dburi,
			debug: self.options.debug,
			session_id: conn_name
		});
		self.db = db;

		db.on('error', function(err) {
			self.logger.log('db', 'error', err);
		});

		db.on('debug', function(msg) {
			self.logger.log('db', 'debug', msg);
		});

		db.on('notice', function(msg) {
			self.logger.log('db', 'debug', 'Notice: ' + msg);
		});

		db.on('end', function() {
			if (db.no_reconnect)
			{
			}
			else
			{
				self.logger.log('db', 'info', 'Database for default session disconnected. Restarting');
				db.connect();
			}
		});

		db.on('connected', function() {
			self.logger.info('app', 'Initial database connection succeeded');
			self.grape_settings.setup(function(err) {
				if (err)
				{
					self.logger.error('db', 'Error while loading settings.', err);
				}
				else
				{
					next();
				}
			});

		});

		self.grape_settings = new GrapeSettings(self);

	};

	this.shutdown = function(in_trap) {
		if (typeof in_trap == 'undefined')
			var in_trap = false;

		self.state = 'shutdown';

		if (self.shutdown_started == 0)
			self.shutdown_started = (new Date()).getTime();

		if (cluster.isMaster)
		{
			self.logger.app('info', 'Starting shutdown sequence on master...');
			self.logger.app('info', 'Shutdown: Disconnect cluster...');
			//setImmediate(function() { cluster.disconnect(); });
			//if (!in_trap)
			//{
				for (var worker_id in cluster.workers)
				{
					self.logger.app('info', 'Shutdown: Sending SIGINT to worker ', cluster.workers[worker_id].process.pid);
					cluster.workers[worker_id].kill('SIGINT');
				}
			//}

			var wait = 5000; // 5 seconds
			var try_interval = 100; // 100 ms

			function all_workers_dead()
			{
				if (Object.keys(cluster.workers).length > 0)
				{
					wait = wait - try_interval;
					if (wait <= 0 && wait > -5000)
					{
						self.logger.app('info', 'Shutdown: Some worker processes seems to be stuck. Sending SIGTERM...');
						for (var worker_id in cluster.workers)
						{
							self.logger.app('info', 'Shutdown: Sending SIGTERM to worker', cluster.workers[worker_id].process.pid);
							cluster.workers[worker_id].kill('SIGTERM');
						}
						setTimeout(all_workers_dead, try_interval);
					}
					else if (wait <= -5000)
					{
						self.logger.app('info', 'Shutdown: Some worker processes are stuck. Sending SIGKILL...');
						for (var worker_id in cluster.workers)
						{
							self.logger.app('info', 'Shutdown: Sending SIGKILL to worker', cluster.workers[worker_id].process.pid);
							cluster.workers[worker_id].kill('SIGKILL');
						}
					}
					else // still giving them some time
					{
						setTimeout(all_workers_dead, try_interval);
					}
				}
				else
				{
					self.logger.app('info', 'Shutdown: All worker processes are now dead');
					self.db.disconnect(true, function() {
						self.logger.app('info', 'Shutdown: Master DB connection disconnected');
					
						self.logger.app('info', 'Shutdown: Disconnecting logger...');
						self.logger.shutdown();
					});
				}
			}
						
			setTimeout(all_workers_dead, try_interval);


		}
		else
		{
			self.logger.app('info', 'Shutdown: Starting shutdown sequence on worker...');
			

			if (self.current_worker && self.current_worker.shutdown)
			{
				self.current_worker.shutdown(function() {
					self.logger.app('info', 'Shutdown: Disconnecting database...');
					self.db.disconnect(true, function() {
						self.logger.app('info', 'Shutdown: Disconnecting logger...');
						self.logger.shutdown(function() {
							cluster.worker.disconnect();
						});
					});
				});
			}
			else
			{
				self.logger.app('info', 'Shutdown: Disconnecting database...');
				self.db.disconnect(true, function() {
					self.logger.app('info', 'Shutdown: Disconnecting logger...');
					self.logger.shutdown(function() {
						cluster.worker.disconnect();
					});
				});
			}
		}
		
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
			self.logger.fatal('app', 'Missing base_directory in configuration'); // TODO add some more info?
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

				self.logger.debug('app', 'Setting up PID file ', pidfile);
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
						self.logger.info("app", "Killing existing process ", old_pid, " (found in pidfile)");
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
					fs.unlinkSync(pidfile);
					var diff = (new Date()).getTime() - self.shutdown_started;
					console.log("Process exit. Shutdown took %s ms", (diff));
				});
				process.on('SIGINT', function(code) {
					if (self.shutdown_started > 0)
					{
						var diff = (new Date()).getTime() - self.shutdown_started;
						if (diff < 5000)
						{
							console.log("Exiting forcefully!");
							process.exit(1);
						}
					}
					
					self.shutdown_started = (new Date()).getTime();

					self.logger.app('info', "Caught SIGINT. Exiting gracefully");
					self.shutdown(true); 
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

			var done = function(next) {
				self.emit('master-after-start');
				next();
			};

			async.series([
				create_pidfile, 
				self.setup_comms, 
				self.setup_database, 
				verify_grape_setup(self),
				start_workers,
				done
			]);
		}
		else  // we are the child/worker process
		{
			process.on('SIGINT', function(code) {
				self.logger.app('info', "Caught SIGINT, exiting gracefully");
				self.shutdown(true); 
			});


			function run_start_function(done) {
				if (process.env.state)
				{
					var instance_count = process.env.instance_count || '0';

					logger.info('app', process.env.state,  '#' + instance_count, 'process pid', process.pid, 'started');
					var process_name = self.options.process_name || 'grape-unknown';

					var found = false;
					for (var i = 0; i < self.workers.length && !found; i++)
					{
						var worker = self.workers[i];

						if (worker.name == process.env.state)
						{
							self.current_worker_definition = worker;

							found = true;
							process.title = [process_name, '-', worker.name, '[', instance_count , ']'].join('');
							try {
								var obj = new (worker.func)(self.options, self);
								self.current_worker = obj;

								self.emit([worker.name, 'beforestart'].join('-'), worker, obj);
							
								if (obj.start)
								{
									obj.start.call(obj, function() { 
										self.emit([worker.name, 'afterstart'].join('-'), worker, obj);
										self.emit('worker', worker, obj);
										done();
									});
								}
								else
								{
									self.logger.warn('app', 'No start() function for worker', worker.name, 'defined');
									self.emit([worker.name, 'afterstart'].join('-'), worker, obj);
									self.emit('worker', worker, obj);
									done();
								}

							} catch (e) {
								self.logger.crit('app', 'Unhandled exception in worker during startup', e);
								//setTimeout(function() { process.exit(8); }, 1);
							}
							
						}
					}

					if (!found)
					{
						console.log("UNKNOWN WORKER " + process.env.state);
					}
				}
			}

			function done(next) {
				self.emit('worker-after-start');
				next();
			};

			async.series([self.setup_comms, self.setup_database, run_start_function, done]);
		}
	};

	this.forkWorker = function(worker, instance_idx) {
		self.logger.info("app", "Starting worker: " + worker.name);
		var new_process = cluster.fork({"state": worker.name, "instance_count": instance_idx});
		new_process.on('online', function() {
			self.logger.info('app', 'Worker process ', worker.name, "[", instance_idx, "] is now online as pid ", new_process.process.pid);
		});

		new_process.on('disconnect', function() {
		});

		new_process.on('exit', function() {
			if (self.state == 'shutdown')
			{
				self.logger.info('app', worker.name, "[" + instance_idx + "]: Worker process", new_process.process.pid, "has shut down");
				return;
			}

			if (new_process.process.exitCode == 5)
			{
				self.logger.error('app', worker.name, "[" + instance_idx + "]: Worker process", new_process.process.pid, "experienced a connectivity issue. Restarting in 5 seconds");
				setTimeout(function() { 
					self.forkWorker(worker, instance_idx); 
				}, 5000);
			}
			else if (new_process.process.exitCode == 8) // unhandled exception
			{
				self.logger.error('app', worker.name, "[" + instance_idx + "]: Worker process", new_process.process.pid, "experienced an Unhandled Exception. Restarting in 5 seconds");
				setTimeout(function() { 
					self.forkWorker(worker, instance_idx); 
				}, 5000);
			}
			else if (new_process.process.exitCode == 9) // fatal error, do not restart
			{
				self.logger.error('app', worker.name, "[", instance_idx, "]: Worker process ", new_process.process.pid, " experienced a fatal error. I am not going to restart the process.");
			}
			else
			{
				self.logger.error('app', worker.name, "[", instance_idx, "]: Worker process ", new_process.process.pid, " exited with code", new_process.process.exitCode);
				setTimeout(function() { 
					self.forkWorker(worker, instance_idx); 
				}, 2000);
			}
		});
		new_process.on('death', function() {
			self.logger.error('app', "Worker died"); // TODO add some more info?
			self.forkWorker(worker, instance_idx);
		});
		new_process.on('message', function(msg, handle) {
			//self.logger.debug('comms', 'Received a message from PID', new_process.process.pid);
			self.comms.handle_message(msg, handle, new_process);
		});
	};

	this.setup();
};


grape.prototype.__proto__ = events.EventEmitter.prototype;
exports = module.exports = grape;


