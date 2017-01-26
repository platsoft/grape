"use strict";
var fs = require('fs');
var path = require('path');
var child_process = require('child_process');

var app;

exports = module.exports = function(_app) {
	app = _app;

/**
 * @desc Add a process to the background process queue
 * @method POST
 * @url
 * @body JSON object containing fields:
 * {
 * 	process_id INTEGER Process ID to start. Provide either this or a process name
 * 	process_name TEXT Process name to start. Provide either this or a process ID
 * 	param JSON Process spesicifc options
 * }
 * @example {"process_name":"create_combined_tape","param":{"submission_date":"2014/05/01"}}
 * @return JSON object containing fields:
 *
 *
 **/
	app.post("/grape/process/start", api_start_process);

/**
 * @desc Add a auto schedule to a process 
 * @method POST
 * @sqlfunc grape.save_process_auto_scheduler
 * @url /grape/process/autoschedule
 * @body JSON object containing fields:
 * {
 * 	process_id INTEGER Process ID to set autoscheduler for 
 * 	auto_scheduler_id INTEGER Optional, and if given this will update the existing auto_scheduler
 * 	day_time TIME Time to run
 * 	scheduled_interval INTERVAL Interval to run (1 hour, 10 minutes, etc). Set either this, or time
 * 	dow TEXT A 7 character string containing 0s or 1s with the date of weeks to run on. Starts on Sunday
 * 	days_of_month TEXT A comma separated list of days to run on, or a * to indicate every day
 * 	params JSON 
 * 	user_id INTEGER Run as user id
 * 	active BOOLEAN
 * }
 * @return JSON object containing fields:
 *
 **/
	app.post("/grape/process/autoschedule", api_process_autoschedule);

/**
 * @desc List processes
 * @method GET
 * @url /grape/process/list
 * @example {"process_name":"create_combined_tape","param":{"submission_date":"2014/05/01"}}
 * @return JSON array with objects containing fields:
 * {
 * 	process_id INTEGER
 * 	pg_function TEXT
 * 	description TEXT
 * 	new INTEGER
 * 	completed INTEGER
 * 	error INTEGER
 * 	running INTEGER
 * }
 * @example [{"process_id":1,"pg_function":"create_combined_tape","description":"Create combine tape","new":1,"completed":0,"error":0,"running":1},{"process_id":2,"pg_function":"apply_tapefile","description":"Apply debit orders","new":0,"completed":0,"error":0,"running":0}]
 **/
	app.get("/grape/process/list", api_list_processes);

/**
 * @desc Get lines from schedule logfile
 * @method GET
 * @url /grape/schedule/:schedule_id/get_logfile
 * @param offset INTEGER Start at line optional
 * @param limit INTEGER Number of lines to retrieve. default 100 optional
 *
 */
	app.get("/grape/schedule/:schedule_id/get_logfile", api_get_schedule_logfile);

/**
 * @desc Get ps_bgworker status
 * @method GET
 * @url /grape/bgworker/status
 * @return Will return field state with either Running or Not running. If the process is running
 * @returnsample { status: 'OK', state: 'Not running' }
 * @returnsample { status: 'OK', state: 'Running', pid: '12497', cmdline: 'ps_bgworker raisin@localhost/raisin [/home/hans/platsoft/raisin]' }
 */
	app.get("/grape/bgworker/status", api_bgworker_status);

/**
 * @desc Start ps_bgworker process
 * @method POST
 * @url /grape/bgworker/start
 *
 */
	app.post("/grape/bgworker/start", api_bgworker_start);

/**
 * @desc Kills ps_bgworker process
 * @method POST
 * @url /grape/bgworker/stop
 *
 */
	app.post("/grape/bgworker/stop", api_bgworker_stop);

/**
 * @desc 
 * @method GET
 * @url /grape/process/:process_id
 *
 */
	app.post("/grape/process/:process_id", api_process_info);

/**
 * @desc 
 * @method GET
 * @url /grape/process/:process_id
 *
 */
	app.get("/download/schedule_logfile/:schedule_id", api_download_schedule_logfile);

/**
 * @desc Starts a process function - this should never be calle from a frontend
 * @method POST
 * @url /grape/process/:process_id/run
 * @body will be passes as the parameters
 * @return JSON object containing output of process
 * 
 *
 **/
	app.post("/grape/process/:process_name/run", api_run_process_now);


/**
 * @desc
 * @url /grape/process/autoscheduler/:autoscheduler_id
 * @method GET
 * @sqlfunc 
 * @return
 */
	app.get("/grape/process/autoscheduler/:autoscheduler_id", 
			function (req, res)
			{
				res.locals.db.jsonb_call('grape.select_auto_scheduler', {autoscheduler_id: req.params.autoscheduler_id}, null, {response: res});
			});

};

function api_run_process_now(req, res)
{
	res.locals.db.jsonb_call('grape.run_process_function', {pg_function: req.params.process_name, params: req.body}, null, {response: res});
}

function api_start_process(req, res)
{
	var obj = req.body;
	res.locals.db.json_call('grape.start_process', obj, null, {response: res});
}

function api_list_processes(req, res)
{
	var obj = {};
	res.locals.db.json_call('grape.list_processes', obj, null, {response: res});
}


function api_get_schedule_logfile (req, res)
{
	var schedule_id = req.params.schedule_id;
	var offset = 0;

	if (req.query.offset)
		offset = parseInt(req.query.offset);

	var limit = 100;
	if (req.query.limit)
		limit = parseInt(req.query.limit);

	res.locals.db.json_call('grape.schedule_info', {schedule_id: req.params.schedule_id}, function(err, result) {
		if (err)
		{
			res.json('{}').end(); //ERROR
			return;
		}

		var obj = result.rows[0]['grapeschedule_info'];
		var schedule = obj.schedule;

		if (schedule.logfile[0] === '~') {
			schedule.logfile = path.join(process.env.HOME, schedule.logfile.slice(1));
		}
		var logfilename = path.resolve(schedule.logfile);

		try {
			var file_contents = fs.readFileSync(logfilename, {encoding: 'utf8'});
			var lines = file_contents.split("\n");
			schedule.lines = lines.splice(offset, limit);

			res.json(schedule);
		}
		catch (e) {
			console.log(e);
			schedule.lines = null;
			res.json(schedule).end(); //ERROR
			return;
		}
	});

}

function api_download_schedule_logfile (req, res)
{
	var schedule_id = req.params.schedule_id;
	var offset = 0;

	res.locals.db.json_call('grape.schedule_info', {schedule_id: req.params.schedule_id}, function(err, result) {
		if (err)
		{
			res.json('{}').end(); //ERROR
			return;
		}

		var obj = result.rows[0]['grapeschedule_info'];
		var schedule = obj.schedule;

		if (schedule.logfile[0] === '~') {
			schedule.logfile = path.join(process.env.HOME, schedule.logfile.slice(1));
		}
		var logfilename = path.resolve(schedule.logfile);

		try {
			res.sendFile(logfilename); 
		}
		catch (e) {
			console.log(e);
			res.send(e).end(); //ERROR
			return;
		}
	});

}


function get_bgworker_status(cb)
{
	var config = app.get('config');
	var ps_bgworker_path = config.ps_bgworker || 'ps_bgworker';

	child_process.exec([ps_bgworker_path, '--status'].join(' '),
		{
			timeout: 2000,
			encoding: 'utf8'
		},
		function(err, stdout, stderr) {
			if (err && !stdout)
			{
				cb(err, {stdout: stdout, stderr: stderr});
				return;
			}

			var obj = {pid: 0, cmdline: ''};

			var lines = stdout.split("\n");
			if (lines[0] == "Not running")
			{
				cb(null, obj);
			}
			else
			{
				lines.forEach(function(line) {
					if (line.trim() != '')
					{
						var ar = line.split(':');
						if (ar.length == 2)
						{
							var k = ar[0];
							if (k == 'PID')
							{
								obj.pid = parseInt(ar[1]);
							}
							else if (k == 'CMDLINE')
							{
								obj.cmdline = ar[1];
							}
						}
					}
				});

				cb(null, obj);
			}
		}
	);

}

function api_bgworker_status(req, res)
{
	get_bgworker_status(function(err, obj) {
		if (err)
		{
			res.status(500).json({'status': 'ERROR', 'error': err}).end();
			return;
		}

		res.status(200).json({
			'status': 'OK',
			'state': obj.pid == 0 ? 'Not running' : 'Running',
			'pid': obj.pid,
			'cmdline': obj.cmdline}
		).end();
	});
}

function api_bgworker_start(req, res)
{
	var config = app.get('config');
	var ps_bgworker_path = config.ps_bgworker || 'ps_bgworker';
	child_process.exec([ps_bgworker_path].join(' '),
		{
			timeout: 2000,
			encoding: 'utf8'
		},
		function(err, stdout, stderr) {
			if (err && !stdout)
			{
				res.status(500).json({'status': 'ERROR', 'error': err}).end();
				return;
			}

			res.status(200).json({'status': 'OK', 'stdout': stdout}).end();
		}
	);
}

function api_bgworker_stop (req, res)
{
	get_bgworker_status(function(err, obj) {
		if (err)
		{
			res.status(500).json({'status': 'ERROR', 'error': err}).end();
			return;
		}
		child_process.execSync('kill ' + obj.pid);
		res.status(200).json({'status': 'OK', 'pid': obj.pid}).end();
	});
}

function api_process_info (req, res)
{
	var obj = req.body;
	res.locals.db.json_call('grape.process_info', obj, null, {response: res})
}

function api_process_autoschedule (req, res)
{
	res.locals.db.json_call('grape.save_process_auto_scheduler', req.body, null, {response: res});
}


