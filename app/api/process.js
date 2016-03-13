"use strict";
var fs = require('fs');
var readline = require('readline');

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


	app.get("/grape/schedule/:process_id/:schedule_id/get_logfile", api_get_schedule_logfile);
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
	console.log(req);

	var line_num_start = 0;
	
	var dte = '';

	file = fs.createReadStream();
}


