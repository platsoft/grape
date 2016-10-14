"use strict";
var app;
var fs = require('fs');
var async = require('async');
var XLSX = require('xlsx');

exports = module.exports = function(_app) {
	app = _app;
/**
 * @desc Upload generic excel data to grape.data_import and rows to data.data_import_row
 * @method POST
 * @url /grape/data_import
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import", api_data_import);

/**
 * @desc delete given data_import_id entries if not processed
 * @method get
 * @url /grape/data_import/:data_import_id/delete
 *
 * @return JSON object 
 **/
	app.get("/grape/data_import/:data_import_id/delete", api_data_import_delete);

/**
 * @desc process given data_import_id data
 * @method get
 * @url /grape/data_import/:data_import_id/process
 *
 * @return JSON object 
 **/
	app.get("/grape/data_import/:data_import_id/process", api_data_import_process);

/**
 * @desc return data for data_import_id
 * @method get
 * @url /grape/data_import/:data_import_id/detail
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/detail", api_data_import_detail);

/**
 * @desc 
 * @method post
 * @url 
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/create_table", api_data_import_test_table_create);

/**
 * @desc 
 * @method post
 * @url 
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/append_table", api_data_import_test_table_append);

/**
 * @desc 
 * @method post
 * @url 
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/remove_table", api_data_import_test_table_drop);

/**
 * @desc 
 * @method post
 * @url 
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/view_table", api_data_import_test_table_select);

/**
 * @desc 
 * @method post
 * @url 
 *
 * @return JSON object 
 **/
	app.post("/grape/data_import/:data_import_id/alter_table", api_data_import_test_table_alter);
};

function api_data_import_test_table_select(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id,
				'options': req.body.options};
	res.locals.db.json_call('grape.data_import_test_table_select', obj, null, {response: res});
}

function api_data_import_test_table_alter(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id};
	res.locals.db.json_call('grape.data_import_test_table_alter', obj, null, {response: res});
}

function api_data_import_test_table_drop(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id};
	res.locals.db.json_call('grape.data_import_test_table_drop', obj, null, {response: res});
}

function api_data_import_test_table_append(req, res)
{
	console.log(JSON.stringify(req.body));
	console.log(req.params.data_import_id);
	var obj = {'data_import_id': req.params.data_import_id,
				'test_table_name': req.body.tablename,
				'append': true};
	res.locals.db.json_call('grape.data_import_test_table_insert', obj, null, {response: res});
}

function api_data_import_test_table_create(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id,
				'test_table_name': req.body.tablename,
				'description': req.body.description};
	res.locals.db.json_call('grape.data_import_test_table_insert', obj, null, {response: res});
}

function api_data_import_delete(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id};
	res.locals.db.json_call('grape.data_import_delete', obj, null, {response: res});
}

function api_data_import_detail(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id, 'offset': req.body.offset, 'limit': req.body.limit};
	res.locals.db.json_call('grape.data_import_detail', obj, null, {response: res});
}

function api_data_import_process(req, res)
{
	var obj = {'data_import_id': req.params.data_import_id};
	res.locals.db.json_call('grape.data_import_process', obj, null, {response: res});
}

function api_data_import(req, res)
{
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
			ds.saveFile('dupload', file.path, filename, false);
			data_import_ids.push(data_import_id);

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
		});
	}
}


