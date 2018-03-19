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
const IPCSessionCache = require(__dirname + '/ipc_sessioncache.js');
const CommsChannel = require(__dirname + '/comms.js');
const GrapeSettings = require(path.join(__dirname, 'grape_settings.js'));
const dblib = require(path.join(__dirname, 'db.js'));

//var email_notification_worker = require(__dirname + '/email_notification_listener.js').EmailNotificationListener;


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

	this.setup = function() {
		self.addWorker({
			name: 'httplistener',
			instance_count: self.options.http_instance_count || 5,
			func: g_app
		});

		/*
		self.addWorker({
			name: 'emailer',
			instance_count: 1,
			func: email_notification_worker
		});
		*/
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

	this.check_grape_version = function(next) {
		try {
			var pkg = JSON.parse(fs.readFileSync(__dirname + '/../../package.json', 'utf8'));
		} catch (e) {
			self.logger.error('app', 'Error when loading package.json');
			next();
			return;
		}

		var db_grape_version = self.grape_settings.get_value('grape_version', '0');
		if (db_grape_version != pkg.version)
		{
			self.logger.crit('app', 'The grape version in your database (', db_grape_version, ') does not match the one that is currently running (', pkg.version, '). Please apply the necessary patches to get your database up too date');
			self.db.disconnect(true); // going to quit
		}
		else
		{
			next();
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

			var done = function(next) {
				self.emit('master-after-start');
				next();
			};

			async.series([
				create_pidfile, 
				self.setup_comms, 
				self.setup_database, 
				self.check_grape_version,
				start_workers,
				done
			]);
		}
		else  // we are the child/worker process
		{
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
							found = true;
							process.title = [process_name, '-', worker.name, '[', instance_count , ']'].join('');
							try {
								var obj = new (worker.func)(self.options, self);

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
			if (new_process.process.exitCode == 5)
			{
				self.logger.error('app', worker.name, "[", instance_idx, "]: Worker process ", new_process.process.pid, " experienced a connectivity issue. Restarting in 5 seconds");
				setTimeout(function() { 
					self.forkWorker(worker, instance_idx); 
				}, 5000);
			}
			else if (new_process.process.exitCode == 8) // unhandled exception
			{
				self.logger.error('app', worker.name, "[", instance_idx, "]: Worker process ", new_process.process.pid, " experienced an Unhandled Exception. Restarting in 5 seconds");
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


