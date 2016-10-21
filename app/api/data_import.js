"use strict";
var app;
var fs = require('fs');
var async = require('async');
var XLSX = require('xlsx');
var csvparse = require('csv-parse');

exports = module.exports = function(_app) {
	app = _app;
/**
 * @desc Upload generic excel data to grape.data_import and rows to data.data_import_row
 * @method POST
 * @url /grape/data_import/upload
 * @body JSON object containing fields:
 * {
 * 	file_data TEXT file data byte string
 * 	name TEXT file name
 * 	type TEXT file type
 * 	processing_parameters JSON Array of objects with parameters
 * 	processing_function TEXT Name of the processing function
 * }
 * @example {file_data:'...', name:'filename.csv', type:'text/csv', processing_parameters:[{x:''}], processing_function:'dimport_function_x'}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/upload", api_data_import);

/**
 * @desc delete given data_import_id entries if not processed
 * @method POST
 * @url /grape/data_import/:data_import_id/delete
 * @body JSON object containing fields:
 * {
 * 	data_import_id INTEGER the id of the data import to delete
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/delete", api_data_import_delete);

/**
 * @desc process given data_import_id data
 * @method post
 * @url /grape/data_import/:data_import_id/process
 * @body JSON object containing fields:
 * {
 * 	data_import_id INTEGER the id of the data import to process 
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/process", api_data_import_process);

/**
 * @desc create a test table from data_import data
 * @method post
 * @url /grape/data_import/test_table/create 
 * @body JSON object containing fields:
 * {
 * 	data_import_id INTEGER the id of the data import data to use for the test table
 * 	table_name TEXT the table name to use for the new test table
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/test_table/create", api_data_import_test_table_create);

/**
 * @desc append data from a data import to an existing compatable test_table
 * @method post
 * @url /grape/data_import/test_table/append 
 * @body JSON object containing fields:
 * {
 * 	test_table_id INTEGER The id of the test table to append to
 *	data_import_id INTEGER the id of the data import data to use for the test table
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/test_table/append", api_data_import_test_table_append);

/**
 * @desc delete an existing test table 
 * @method post
 * @url /grape/data_import/test_table/delete
 * @body JSON object containing fields:
 * {
 * 	test_table_id INTEGER The id of the test table to delete
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/test_table/delete", api_data_import_test_table_drop);

/**
 * @desc alter an existing test table
 * @method post
 * @url /grape/data_import/test_table/alter 
 * @body JSON object containing fields:
 * {
 * 	TODO
 * }
 * @example {}
 * @return JSON object {status:'OK'} or {status: 'ERROR', message:'error message'}
 **/
	app.post("/grape/data_import/test_table/alter", api_data_import_test_table_alter);
};

function api_data_import_test_table_alter(req, res)
{
	res.locals.db.json_call('grape.data_import_test_table_alter', req.body, null, {response: res});
}

function api_data_import_test_table_drop(req, res)
{
	res.locals.db.json_call('grape.data_import_test_table_drop', req.body, null, {response: res});
}

function api_data_import_test_table_append(req, res)
{
	req.body.append = true;
	res.locals.db.json_call('grape.data_import_test_table_insert', req.body, null, {response: res});
}

function api_data_import_test_table_create(req, res)
{
	res.locals.db.json_call('grape.data_import_test_table_insert', req.body, null, {response: res});
}

function api_data_import_delete(req, res)
{
	res.locals.db.json_call('grape.data_import_delete', req.body, null, {response: res});
}

function api_data_import_process(req, res)
{
	res.locals.db.json_call('grape.data_import_process', req.body, null, {response: res});
}

function api_data_import(req, res)
{
	console.log(req);
	var item_count = 0;
	var errors = [];
	var data_import_ids = [];
	var item_queue =  async.queue(function(task, callback) {
		res.locals.db.json_call('grape.data_import_row_insert', task, function(err, result) { 
			callback();
			item_count++;
		}, {});
	}, 10);
	
	item_queue.drain = function() {
		var count_done = data_import_ids.length;
		for (var i = 0; i < data_import_ids.length; i++)
		{
			res.locals.db.json_call('grape.data_import_done', {data_import_id: data_import_ids[i]}, function (err, result) {
				count_done--;
				if (count_done <= 0)
				{
					res.status(200).json({'status': 'OK', 'row_count': item_count, data_import_id: data_import_ids});
				}
			});
		}
	};
	
	var filefields = Object.keys(req.files);

	if (filefields.length == 0)
	{
		res.status(200).json({'status': 'ERROR', 'message': 'No files', 'code': -1});
	}

	for (var i = 0; i < filefields.length; i++)
	{
		var file = req.files[filefields[i]];
		var ds = app.get('document_store');
		var description = req.body.description;
		var processing_function = req.body.processing_function;
		var processing_param = JSON.parse(req.body.processing_param);

		res.locals.db.json_call('grape.data_import_insert', {processing_function: processing_function, filename: file.originalFilename, description: description, processing_param: processing_param}, function(err, result) { 
			
			var data_import_id = result.rows[0].grapedata_import_insert.data_import_id;
			var originalname = file.originalFilename; 
			var filename = originalname.replace(/.*(\.[^.]*$)/, 'data_import_'+data_import_id+'$1')
			ds.saveFile('dimport', file.path, filename, false);
			data_import_ids.push(data_import_id);
			if (file.type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || file.type == 'application/vnd.ms-excel') {
				var workbook = XLSX.readFile(file.path);
				var first_sheet_name = workbook.SheetNames[0];
				var worksheet = workbook.Sheets[first_sheet_name];
				
				var range = worksheet['!ref'];
				var ar = range.split(':');

				var d = XLSX.utils.decode_range(range);

				var max_col = d.e.c;
				var max_row = d.e.r;

				var headers = [];
				for (var col = 0; col <= max_col; col++)
				{
					var address = XLSX.utils.encode_cell({r: 0, c: col});
					headers.push(worksheet[address].v);
				}

				for (var row = 1; row <= max_row; row++)
				{
					var data = {data:{}};
					data['data_import_id'] = data_import_id;
					for (var col = 0; col <= max_col; col++)
					{
						var val = '';
						var address = XLSX.utils.encode_cell({r: row, c: col});
						if (worksheet[address])
							val = worksheet[address].v;
						
						data.data[headers[col]] = val;
					}
					
					item_queue.push(data);

				}
				
				if (row == 1)
					item_queue.drain();
			}
			else if (file.type == 'text/csv') {
				var rs = fs.createReadStream(file.path);
				
				var parser = csvparse({columns: true}, function(err, data) {
					//TODO error check
					for (var i = 0; i < data.length; i++)
					{
						var row = {data:{}}
						row['data_import_id'] = data_import_id;
						row.data = data[i];
						
						item_queue.push(row);
					}
				});

				rs.pipe(parser);
			}
		});
	}
}

