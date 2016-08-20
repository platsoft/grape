
module.exports = function(app) {
	function validate_object(obj, validation_string)
	{
		var ret = auto_validate.validate(obj, validation_string);
		if(ret.errors && ret.errors.length > 0)
		{
			throw new Error('Validation failure: ' + ret.errors[0]);
		}
		else {
			_.each(ret.obj, function(entry) {
				if (entry.valid == false)
				{
					console.log(entry);
					throw new Error('Invalid field data: ' + entry.name, entry);
				}
				obj[entry.name] = entry.value;
			});
			return obj;
		};
	}

	app.validate_input = function(req, validation_string) {
		var obj = req.body;
		_.each(_.keys(req.params), function(field) {
			req.body[field] = req.params[field];
		});

		if (validation_string)
		{
			obj = validate_object(obj, validation_string);
		}

		return obj;
	};

	app.default_api_schema = 'public';

	/*
	param : {
		name,
		method,
		url,
		db_function,
		validation_string
	}
	 */
	app.add_api_call = function(param)
	{
		var self = this;
		if(!param.api_function || typeof(param.api_function) != typeof Function)
		{
			if (!param.db_function)
				throw new Error('No db_function provided');

			param.api_function = function(req, res) {
				try
				{
					var obj = self.validate_input(req, param.validation_string);

					res.locals.db.json_call(param.db_function, obj, null, {response: res});
				}
				catch (e)
				{
					logger.error(e.stack);
					res.send({
						status: 'ERROR',
						message: e.message,
						code: -99,
						error: e
					});
				}
			}
		}

		// Validation
		if (!param) return;
		if (param.method != 'get' && param.method != 'post')
			throw new Error('Invalid API method provided: ' + param.method);
		if (!param.url)
			throw new Error('No url provided');

		logger.info('Registering API call ' + param.name + ' as ' + param.method + ':' + param.url);
		if (param.method == 'get')
		{
			self.get(param.url, param.api_function);
		}
		else if (param.method == 'post')
		{
			self.post(param.url, param.api_function);
		}
	}

	app.create_api_calls = function (param)
	{
		var self = this;
		if (!param) return;
		if (!param.url_prefix)
			param.url_prefix = '';

		if (param.url_prefix.slice(-1) != '/')
			param.url_prefix = param.url_prefix + '/';

		if (!param.db_schema)
			param.db_schema = app.default_api_schema || 'public';

		var key_val = param.param_id;
		if( !key_val )
			key_val = param.name + '_id';

		for (var i = 0; i < param.operations.length; i++)
		{
			entry = param.operations[i];
			op = entry.name;

			if (op == 'view')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'get',
					url               : param.url_prefix + param.name + '/:' + key_val,
					db_function       : entry.db_function ? entry.db_function : param.db_schema + '.view_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else if (op == 'create')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name,
					db_function       : entry.db_function ? entry.db_function : param.db_schema + '.save_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else if (op == 'update')
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name + '/:' + key_val,
					db_function       : entry.db_function ? entry.db_function : param.db_schema + '.save_' + param.name,
					validation_string : entry.validation_string
				});
			}
			else
			{
				self.add_api_call({
					name              : param.name + '.' + op,
					method            : 'post',
					url               : param.url_prefix + param.name + '/:' + key_val + '/' + op,
					db_function       : entry.db_function ? entry.db_function : param.db_schema + '.' + op + '_' + param.name,
					validation_string : entry.validation_string
				});
			}
		}
	};

};


