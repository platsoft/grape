"use strict";
var fs = require('fs');
var path = require('path');
var child_process = require('child_process');
var process = require('process');
var bgworker_lib = require(path.resolve(__dirname + '/../lib/ps_bgworker'));

var app;

exports = module.exports = function(_app) {
	app = _app;

/**
 * @desc Add a process to the background process queue
 * @method POST
 * @url /grape/process/start
 * @body 
 * {
 * 	process_id INTEGER Process ID to start. Provide either this or a process name
 * 	process_name TEXT Process name to start. Provide either this or a process ID
 * 	param JSON Process specific options
 * 	time_sched TIMESTAMPTZ When to run this (default to now)
 * }
 * @example {"process_name":"create_combined_tape","param":{"submission_date":"2014/05/01"}}
 * @return JSON object containing fields:
 *
 *
 **/
//	app.post("/grape/process/start", api_start_process);

/**
 * @desc Add a auto schedule to a process 
 * @sqlfunc grape.save_process_auto_scheduler
 * @body 
 * {
 * 	auto_scheduler_id INTEGER Optional, and if given this will update the existing auto_scheduler
 * 	day_time TIME Time to run
 * 	scheduled_interval INTERVAL Interval to run (1 hour, 10 minutes, etc). Set either this, or time
 * 	dow TEXT A 7 character string containing 0s or 1s with the date of weeks to run on. Starts on Sunday
 * 	days_of_month TEXT A comma separated list of days to run on, or a * to indicate every day
 * 	params JSON 
 * 	user_id INTEGER Run as user id
 * 	active BOOLEAN
 * }
 *
 **/

/**
 * @desc List processes
 * @method GET
 * @url /grape/process/list
 * @return JSON array with objects containing fields:
 * {
 * 	process_id INTEGER
 * 	pg_function TEXT
 * 	description TEXT
 * 	process_category TEXT
 * 	param JSON
 * 	auto_scheduler [
 * 		
 * 		run_as_user
 * 	]
 * 	process_role [TEXT]
 * 	schedule_id INTEGER
 * 	time_sched
 * 	time_started
 * 	time_ended
 * 	pid
 * 	sched_param
 * 	sched_username
 * 	logfile
 * 	status
 * 	progress_completed
 * 	progress_total
 * 	auto_scheduler_id
 * }
 * @returnsample [{"process_id":1,"pg_function":"create_combined_tape","description":"Create combine tape","new":1,"completed":0,"error":0,"running":1},{"process_id":2,"pg_function":"apply_tapefile","description":"Apply debit orders","new":0,"completed":0,"error":0,"running":0}]
 **/
//	app.get("/grape/process/list", api_list_processes);

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
//	app.get("/grape/bgworker/status", api_bgworker_status);

/**
 * @desc Start ps_bgworker process
 * @method POST
 * @url /grape/bgworker/start
 *
 */
//	app.post("/grape/bgworker/start", api_bgworker_start);

/**
 * @desc Kills ps_bgworker process
 * @method POST
 * @url /grape/bgworker/stop
 *
 */
//	app.post("/grape/bgworker/stop", api_bgworker_stop);

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
			schedule.total_rows = lines.length;
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



