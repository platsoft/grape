"use strict";
var app;
var fs = require('fs');
var async = require('async');
var XLSX = require('xlsx');
var _ = require('underscore');
var csvparse = require('csv-parse');
var ds = null;

exports = module.exports = function(_app) {
	app = _app;

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
 * @desc download the data import file uploaded for specific data_import
 * @method get
 * @url /download/data_import/:data_import_id/:filename
 * @body
 * @example {}
 * @return file buffer
 **/
	app.get("/download/data_import/:data_import_id/:filename", api_data_import_download);

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
//	app.post("/grape/data_import/test_table/create", api_data_import_test_table_create);

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

//function api_data_import_test_table_append(req, res)
//{
//	req.body.append = true;
//	res.locals.db.json_call('grape.data_import_test_table_insert', req.body, null, {response: res});
//}


function api_data_import_delete(req, res)
{
	res.locals.db.json_call('grape.data_import_delete', req.body, null, {response: res});
}

function api_data_import_download(req, res)
{
	var filename = req.params.filename;
	var extension = filename.match(/\.[^\.]*$/)
	var data_import_id = req.params.data_import_id;
	var ds = app.get('document_store');
	var location = ds.getDirectory('dimport');
	location = [location, 'data_import_'+data_import_id+extension].join('/');
	res.download(location, filename);
}



