"use strict";
var app;
var fs = require('fs');
//var e = require(__dirname + '/../lib/excel2007');
//var h = require(__dirname + '/../lib/hexavigesimal');
var async = require('async');
var XLSX = require('xlsx');

exports = module.exports = function(_app) {
	app = _app;
/**
 * @desc Upload generic excel data to grape.data_import and rows to data.data_import_row
 * @method POST
 * @url /grape/data_upload
 *
 * @return JSON object 
 **/
	app.post("/grape/data_upload", api_data_upload);
};

function api_data_upload(req, res)
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
			res.locals.db.json_call('grape.data_upload_done', {data_import_id: data_import_ids[i]}, function (err, result) {
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

		res.locals.db.json_call('grape.data_import_insert', {filename: file.originalFilename, description: filefields[i]}, function(err, result) { 

			var data_import_id = result.rows[0].grapedata_import_insert.data_import_id;
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
				var data = {};
				data['data_import_id'] = data_import_id;
				for (var col = 0; col <= max_col; col++)
				{
					var val = '';
					var address = XLSX.utils.encode_cell({r: row, c: col});
					if (worksheet[address])
						val = worksheet[address].v;
					
					data[headers[col]] = val;
				}
				
				item_queue.push(data);

			}

			if (row == 1)
				item_queue.drain();

			/*
			var doc = new e.Document();
			var reader = new e.Excel2007Reader(file.path, doc);
			reader.openFile();
			console.log(doc.workSheetNames);
			var w = doc.getWorkSheetByName(doc.workSheetNames[0]);
			var headers = w.rows[0].getAllCellValues();

			for (var j = 1; j < w.rows.length; j++)
			{
				var data = {};
				var row = w.rows[j];
				for (var col in headers)
				{
					if (headers.hasOwnProperty(col))
						data[headers[col]] = row.getFormattedCellValueAt('' + col + (j+1));
				}
				data['data_import_id'] = data_import_id;
				item_queue.push(data);
			}

			if (j == 1) 
			{
				item_queue.drain();
			}
			*/
		});
	}
}


