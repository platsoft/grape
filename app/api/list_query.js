"use strict";
var app;

exports = module.exports = function(_app) {
	app = _app;

/**
 * @desc List records from a table or view
 * @method  POST
 * @url /list
 * @input JSON object containing:
 * 	tablename text Table or view name
 * 	sortfield text optional Field to order by
 * 	limit integer optional Record limit default 50
 * 	offset integer optional Record offset default 0
 * 	filter json array optional Filters containing fields:
 * 		field text Field to filter on
 * 		operand text One of '=', '>', '<', '>=', '<='
 * 		value text Filter value
 *
 * @return JSON object containing fields:
 * 	result_count integer Number of results returned
 * 	offset integer Result offset
 * 	limit integer Results limit
 * 	records array Returned records
 * 	total integer Total number of records in the database (after filter has been applied)
 *
 * @example {"result_count":1,"offset":0,"limit":5,"records":[{"stock_item_id":4,"description":"Refining Mist (200ml)"}],"total":1} 
 **/
	app.get("/grape/list", api_list_query);
};

function api_list_query(req, res)
{
	var obj = req.body;
	
	res.locals.db.json_call('grape.list_query', obj, null, {response: res})
}


