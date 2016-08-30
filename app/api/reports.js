"use strict";
var fs = require('fs');

var app;

exports = module.exports = function(_app) {
	app = _app;

/**
 * @desc Save a report
 * @method POST
 * @url /grape/report/save
 * @body JSON object containing fields:
 * { 
 * 	report_id INTEGER Report ID to update optional
 * 	name TEXT Process ID to start. Provide either this or a process name
 * 	description TEXT Description of report for users optional
 * 	function_name TEXT Function name to run
 * 	function_schema TEXT Schema where to find function 
 * 	param JSON Report specific fields
 * }
 * @return JSON object containing statuscode and report_id
 * 
 **/
	app.post("/grape/report/save", api_save_report);

/**
 * @desc Execute a report
 * @method POST
 * @url /grape/execute_report
 * @body JSON object containing fields:
 * { 
 * 	report_id INTEGER Report ID to execute optional
 * 	name TEXT Report name to execute optional
 * 	params JSON Report specific fields
 * }
 * @return JSON object containing statuscode and report_id
 * 
 **/
	app.post("/grape/execute_report", api_execute_report);

/**
 * @desc Execute a report providing parameters in query string
 * @method GET 
 * @url /grape/execute_report/:report_id
 * @param params JSON object containing parameters optional
 * @return JSON object containing statuscode and report_id
 * 
 **/
	app.get("/grape/execute_report/:reportname", api_execute_report);

};

function api_save_report(req, res)
{
	var obj = req.body;
	res.locals.db.json_call('grape.save_report', obj, null, {response: res})
}

function api_execute_report(req, res)
{
	var obj;
	var destination = '';
	var DS = app.get('document_store');
	
	if (req.method == 'GET')
	{
		obj = {};
		obj['name'] = req.params.reportname;
		if (req.query.params)
			obj['params'] = req.query.params;
	}
	else if (req.method == 'POST')
	{
		obj = {};

		if (req.body.name)
			obj['name'] = req.body.name;
		else if (req.body.report_id)
			obj['report_id'] = req.body.report_id;
		else
		{
			//TODO error
			res.json('{}').end();
			return;
		}

		if (req.body.parameters)
			obj['params'] = req.body.parameters;
		else if (req.body.params)
			obj['params'] = req.body.params;
		
		if (req.body.destination)
		{
			destination = req.body.destination;
		}
	}
	else
	{
		//TODO error
		res.json('{}').end();
		return;
	}

	if (destination == '')
	{
		res.locals.db.json_call('grape.execute_report', obj, null, {response: res});
	}
	else if (destination == 'file')
	{
		obj.pg_temp_directory = app.get('config').pg_temp_directory;
		obj.destination = 'file';
		var output_directory = DS.getDirectory('reports/' + req.params.reportname);
		var filename = output_directory;

		res.locals.db.json_call('grape.execute_report', obj, function(err, res) {
			
		}); 
	}
}

