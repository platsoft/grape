"use strict";
var fs = require('fs');
var async = require('async');
var XLSX = require('xlsx');
var _ = require('underscore');
var csvparse = require('csv-parse');
var ds = null;

module.exports = function() {

	function process_data_import_file(file, data_import_id, item_queue)
	{
		var originalname = file.originalFilename; 
		var filename = originalname.replace(/.*(\.[^.]*$)/, 'data_import_' + data_import_id + '$1')
		ds.saveFile('dimport', file.path, filename, false);

		if (originalname.search('.xls') != -1 || originalname.search('.xlsx') != -1 )
		{
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
				if (worksheet[address])
					headers.push(worksheet[address].v.replace(/[^A-Z]/gi, '').toLowerCase());
				else
					headers.push(address.toLowerCase());
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
		else if (originalname.search('.csv') != -1 ) 
		{
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

	}




	return function(req, res) {
		ds = req.app.get('document_store');

		var item_count = 0;
		var errors = [];
		var data_import_ids = [];
		var item_queue =  async.queue(function(task, callback) {
			res.locals.db.json_call('grape.data_import_row_insert', task, function(err, result) { 
				item_count++;
				callback();
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
			return;
		}

		var description = req.body.description;
		var processing_function = req.body.processing_function;
		var processing_param = {};

		try {
			processing_param = JSON.parse(req.body.processing_param);
		} catch (e) { processing_param = {}; }


		for (var i = 0; i < filefields.length; i++)
		{
			var file_field = req.files[filefields[i]];
			if (!_.isArray(file_field))
				var files = [file_field];
			else
				var files = file_field;

			files.forEach(function(file) {

				res.locals.db.json_call('grape.data_import_insert', 
				{	processing_function: processing_function, 
					filename: file.originalFilename, 
					description: description, 
					processing_param: processing_param
				}, function(err, result) { 
					
					var data_import_id = result.rows[0].grapedata_import_insert.data_import_id;
					data_import_ids.push(data_import_id);

					process_data_import_file(file, data_import_id, item_queue);
				});
			});
		}

	
	
	};
};

