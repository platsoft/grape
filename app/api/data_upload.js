"use strict";
var app;
var fs = require('fs');
var e = require(__dirname + '/../lib/excel2007');
var h = require(__dirname + '/../lib/hexavigesimal');
var async = require('async');

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
		res.status(200).json({'status': 'OK', 'row_count': item_count, data_import_id: data_import_ids});
	};
	
	var fieldnames = Object.keys(req.files);

	for (var i = 0; i < fieldnames.length; i++)
	{
		var file = req.files[fieldnames[i]];

		res.locals.db.json_call('grape.data_import_insert', {filename: file.originalFilename, description: fieldnames[i], body: req.body}, function(err, result) { 

			var data_import_id = result.rows[0].grapedata_import_insert.data_import_id;
			data_import_ids.push(data_import_id);

			//TODO handle csv and xls
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
				for (var i = 0; i < headers.length; i++)
				{
					data[headers[i]] = row.getFormattedCellValueAt('' + h.decimal2bijb26(i+1) + (j+1));
					
				}
				data['data_import_id'] = data_import_id;
				item_queue.push(data);
			}

		});
	}
}


