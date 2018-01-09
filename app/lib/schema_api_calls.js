var fs = require('fs');
const path = require('path');
var util = require('util');
var _ = require('underscore');
var Validator = require('jsonschema').validate;
var GrapeAutoValidator = require(__dirname + '/auto_validate.js').validate;

function create_schema_api_call(app, obj)
{
	app.get('logger').info('api', "Creating API call for " + obj.name + " (" + (obj.id || obj.url || 'undefined') + ")");

	var param = {
		roles: [],
		type: 'object',
		method: null,
		sqlfunc: null,
		sqlfunctype: 'json',
		no_validation: false
	};
	_.extend(param, obj);

	if (!param.method)
	{
		if (param.type == 'object')
			param.method = 'POST';
		else if (param.type.toLowerCase() == 'query')
			param.method = 'GET';
	}

	if (!param.id && param.url)
		param.id = param.url;

	if (!param.id)
	{
		app.get('logger').error('api', 'No ID/URL defined in ' + util.inspect(param));
		return;
	}

	if (param.roles)
	{
		add_schema_access_roles(param.roles, param.id, param.method, app.get('db'));
	}

	var auto_validate = function(obj, param, res) {
		if (!param.validate && param.validation_string)
			param.validate = param.validation_string;

		if (param.validate && param.no_validation === false)
		{
			var validate_result = GrapeAutoValidator(obj, param.validate);
			if (validate_result.errors.length > 0)
			{
				app.get('logger').error('api', 'Validation failed for input ' + util.inspect(obj));
				res.send({
					status: 'ERROR',
					message: 'Validation failed',
					code: -3,
					error: validate_result.errors
				});
				return false;
			}
		}

		return true;
	};

	if (param.method == 'POST')
	{
		var func_db_call = function(req, res) {
			try
			{
				var obj = req.body;
				if (obj !== null && obj !== undefined)
				{
					var keys = Object.keys(req.params);
					for (var i = 0; i < keys.length; i++)
						if (!obj.hasOwnProperty(keys[i]))
							obj[keys[i]] = req.params[keys[i]];
				}

				if (param.no_validation === false)
				{
					if (param.validate || param.validation_string)
					{
						if (auto_validate(obj, param, res) === false) { return; }
					}
					else
					{
						var validate_result = Validator(obj, param);

						if (validate_result.errors.length > 0)
						{
							app.get('logger').error('api', 'Validation failed for input ' + util.inspect(obj));
							res.send({
								status: 'ERROR',
								message: 'Validation failed',
								code: -3,
								error: validate_result.errors
							});
							return;
						}
					}
				}

				if (param.sqlfunctype == 'jsonb')
					res.locals.db.jsonb_call(param.sqlfunc, obj, null, {response: res});
				else
					res.locals.db.json_call(param.sqlfunc, obj, null, {response: res});
			}
			catch (e)
			{
				app.get('logger').error(e.stack);
				res.send({
					status: 'ERROR',
					message: e.message,
					code: -99,
					error: e
				});
			}
		};

		app.post(param.id, [func_db_call]);
	}
	else
	{
		var func_db_call = function(req, res) {
			try
			{
				var obj = req.params;

				if (auto_validate(obj, param, res) === false) { return; }

				if (param.sqlfunctype == 'jsonb')
					res.locals.db.jsonb_call(param.sqlfunc, obj, null, {response: res});
				else
					res.locals.db.json_call(param.sqlfunc, obj, null, {response: res});
			}
			catch (e)
			{
				app.get('logger').error(e.stack);
				res.send({
					status: 'ERROR',
					message: e.message,
					code: -99,
					error: e
				});
			}
		};

		app.get(param.id, [func_db_call]);
	}
}

function read_schema_file(app, file, relative) {
	app.get('logger').info('api', "Loading schema file " + relative);
	var data = JSON.parse(fs.readFileSync(file, 'utf8'));

	if (util.isArray(data))
	{
		data.forEach(function (d) {
			create_schema_api_call(app, d);
		});
	}
	else if (util.isObject(data))
	{
		create_schema_api_call(app, data);
	}
	else
	{
		app.get('logger').warn('api', "Unknown type in JSON file " + file);
	}
};

function add_schema_access_roles(roles, url, method, db)
{
	db.query("SELECT grape.add_access_path($1, $2, $3)", [url.replace(/:[a-z_]+/g, '.*'), roles, [method]], function(err, res) {
	});
}

/**
 * Loads schemas from directory
 */
module.exports.load_schemas = function (app, dirname, relativedirname) {
	var options = app.get('options');

	//make sure last character is a /
	if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

	if (dirname[dirname.length - 1] != '/') dirname += '/';

	var files = fs.readdirSync(dirname);
	for (var i = 0; i < files.length; i++)
	{
		var file = files[i];
		var fstat = fs.statSync(path.join(dirname, file));
		if (fstat.isFile())
		{
			if (path.extname(path.join(dirname, file)) == '.json')
			{
				// loads the api module and execute the export function with the app param.
				try {
					module.exports.read_schema_file(app, [dirname, file].join('/'), relativedirname + file);
				} catch (e) {
					app.get('logger').error('api', "Failed to load API file " + relativedirname + file + ' [' + util.inspect(e) + ']');
				}
			}
		}
		else if (fstat.isDirectory())
		{
			module.exports.load_schemas(app, dirname + '/' + file, relativedirname + file);
		}
	}


}

module.exports.read_schema_file = read_schema_file;
