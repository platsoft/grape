var fs = require('fs');
const path = require('path');
var util = require('util');
var _ = require('underscore');
var GrapeAutoValidator = require(__dirname + '/../auto_validate.js').validate;

function create_schema_api_call(app, obj)
{
	app.get('logger').debug('api', "Creating API call for " + obj.name + " (" + (obj.id || obj.url || 'undefined') + ")");

	var param = {
		roles: [],
		type: 'object',
		method: null,
		no_validation: false,
		filename: null 		// filename in which this api call is defined
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
		return false;
	}

	if (!param.roles || !param.roles.length)
	{
		app.get('logger').error('api', 'No roles defined for the API call', param.name, 'No-one will be able to use it');
		return false;
	}
	
	if (param.jsfile)
	{
		var full_path = path.normalize(param.jsfile);

		if (!path.isAbsolute(full_path))
			full_path = path.join(path.dirname(param.filename), full_path);

		param.jsfunc = require(full_path)();
	}
	else if (param.sqlfunc)
	{
	}
	else
	{
		app.get('logger').error('api', 'No handler (sqlfunc or jsfile) is defined for the API call', param.name, 'No-one will be able to use it');
		return false;
	}

	var auto_validate = function(obj, param, res) {
		if (!param.validate && param.validation_string)
			param.validate = param.validation_string;

		if (param.validate && param.no_validation == false)
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

	let load_params_and_query = function(req) {
		var obj = req.body || {};

		var keys = Object.keys(req.params);
		for (var iParam = 0; iParam < keys.length; iParam++)
		{
			if (!obj.hasOwnProperty(keys[iParam]))
			{
				let val = req.params[keys[iParam]];
				if (val === 'null') { val = null; }
				else if (val === 'undefined') { val = undefined; }

				obj[keys[iParam]] = val;
			}
		}

		keys = Object.keys(req.query);
		for (var iQuery = 0; iQuery < keys.length; iQuery++)
		{
			let val = req.query[keys[iQuery]];
			if (val === 'null') { val = null; }
			else if (val === 'undefined') { val = undefined; }

			if (!obj.hasOwnProperty(keys[iQuery]))
				obj[keys[iQuery]] = val;
		}

		return obj;
	};

	if (param.method == 'POST')
	{
		var func_db_call = function(req, res) {
			try
			{
				var obj = load_params_and_query(req);

				keys = Object.keys(req.query);
				for (var iQuery = 0; iQuery < keys.length; iQuery++)
				{
					if (!obj.hasOwnProperty(keys[iQuery]))
						obj[keys[iQuery]] = req.query[keys[iQuery]];
				}

				if (param.no_validation === false)
				{
					if (param.validate || param.validation_string)
					{
						if (auto_validate(obj, param, res) === false) { return; }
					}
				}

				if (param.sqlfunctype == 'jsonb')
				{
					res.locals.db.jsonb_call(param.sqlfunc, obj, null, {response: res});
				}
				else if (param.sqlfunctype == 'json')
				{
					res.locals.db.json_call(param.sqlfunc, obj, null, {response: res});
				}
				else if (param.jsfunc)
				{
					try {
						param.jsfunc(req, res);
					} catch (e) {
						console.log(e);
						res.status(500).end();
					}
				}
				else
				{
					res.locals.db.json_call(param.sqlfunc, obj, null, {response: res});
				}

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
				var obj = load_params_and_query(req);

				if (auto_validate(obj, param, res) === false) { return; }

				if (param.sqlfunctype == 'jsonb')
					res.locals.db.jsonb_call(param.sqlfunc, obj, null, {response: res});
				else if (param.sqlfunctype == 'json')
					res.locals.db.json_call(param.sqlfunc, obj, null, {response: res});
				else if (param.jsfunc)
				{
					try {
						param.jsfunc(req, res);
					} catch (e) {
						console.log(e);
						res.status(500).end();
					}
				}
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

	return {
		name: param.name,
		url: param.id,
		method: param.method,
		roles: param.roles
	};
}

function read_schema_file(app, file, relative) {
	app.get('logger').debug('api', "Loading schema file " + relative);
	var data = JSON.parse(fs.readFileSync(file, 'utf8'));

	var list = [];

	if (util.isArray(data))
	{
		data.forEach(function (d) {
			d.filename = file;
			var obj = create_schema_api_call(app, d);
			if (obj)
				list.push(obj);
		});
	}
	else if (util.isObject(data))
	{
		data.filename = file;
		var obj = create_schema_api_call(app, data);
		if (obj)
			list.push(obj);
	}
	else
	{
		app.get('logger').warn('api', "Unknown type in JSON file " + file);
	}
	return list;
};

// can hopefully be removed
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
	var list = [];

	//make sure last character is a /
	if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

	if (dirname[dirname.length - 1] != '/') dirname += '/';

	try {
		var files = fs.readdirSync(dirname);
	} catch (e) {
		app.get('logger').error('api', 'Failed to load schemas from API directory ', dirname);
		return list;
	}
	for (var i = 0; i < files.length; i++)
	{
		var file = files[i];
		var fstat = fs.statSync(path.join(dirname, file));
		if (fstat.isFile())
		{
			if (path.extname(path.join(dirname, file)) == '.json')
			{
				try {
					var ar = module.exports.read_schema_file(app, path.join(dirname, file), relativedirname + file);
					list = list.concat(ar);
				} catch (e) {
					app.get('logger').error('api', "Failed to load API file " + relativedirname + file + ' [' + util.inspect(e) + ']');
				}
			}
		}
		else if (fstat.isDirectory())
		{
			var ar = module.exports.load_schemas(app, dirname + '/' + file, relativedirname + file);
			list = list.concat(ar);
		}
	}

	return list;
}

module.exports.read_schema_file = read_schema_file;
