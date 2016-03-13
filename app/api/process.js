"use strict";
var fs = require('fs');

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
};

function api_start_process(req, res)
{
	var obj = req.body;
	res.locals.db.json_call('grape.start_process', obj, null, {response: res})
}

function api_list_processes(req, res)
{
	var obj = {};
	res.locals.db.json_call('grape.list_processes', obj, null, {response: res})
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
		console.log(obj.schedule);
		
		var config = app.get('config');
		
		var logfilename = config.document_store + '/' + schedule.logfile;
		
		var file_contents = fs.readFileSync(logfilename, {encoding: 'utf8'});
		var lines = file_contents.split("\n");

		var return_lines = lines.splice(offset, limit);

		res.json(return_lines);
	});

}


