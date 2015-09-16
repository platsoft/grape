

/**
 * Validate string syntax:
 * 	begin_expr ::= "(" <begin_expr> "," <param-def> ")"
 *	param-def ::= <param-name> ":" <data-type> <modifier-list>
 *	modifier-list ::= <opt-modifier> <modifier-list>
 *	opt-modifier ::= "*" | "E" | "0" | ""
 *	data-type ::= "s" | "i" | "f" | "b" | "d" | "t"
 *
 *
 *
 */
function decode_validation_string (validate_string)
{
	var ret = [];
	var i = 0;
	var state = '';
	var var_name = '';
	var var_info = '';

	function save ()
	{
		if (typeof var_info == 'object')
		{
			ret.push({'name': var_name, 'data_type': 'o', 'fields': var_info});
		}
		else // is a string
		{
			var modifiers = {'name': '',
				'data_type': '',
				'original_value': '',
				'value': '',
				'valid': false,
				'nullable': false,
				'optional': false,
				'empty_becomes_null': false
			};

			for (var i = 0; i < var_info.length; i++)
			{
				switch (var_info[i])
				{
					case 's': case 'i': case 'f': case 'b': case 'd': case 't': case 'a':
						modifiers.data_type = var_info[i];
						continue;
					case '*':
						modifiers.optional = true;
						continue;
					case '0':
						modifiers.nullable = true;
						continue;
					case 'E':
						modifiers.empty_becomes_null = true;
						continue;
					default:
						continue;
				}
			}

			modifiers.name = var_name;
			ret.push(modifiers);
		}
	}

	for (i = 0; i < validate_string.length; i++)
	{
		var c = validate_string[i];
		switch (c)
		{
			case '(':
				if (state == '')
				{
					//expecting a variable next
					state = 'var_name';
					var_name = '';
				}
				else if (state == 'var_info') //nested object'
				{
					var_info = decode_validation_string (validate_string.substring(i));
					while (validate_string[i] != ')')
						i++;
				}
				continue;
			case ':':
				//done with var_name, expecting variable info next
				state = 'var_info';
				var_info = '';
				continue;
			case ',':
				save();
				state = 'var_name';
				var_name = '';
				//we can save var_name and var_info now
				continue;
			case ')':
				save();
				return ret;

			default:
				switch (state)
				{
					case 'var_name':
						if (c == ' ' || c == '\n' || c == '\t' || c == '\r')
							continue;
						var_name = var_name + c;
						continue;
					case 'var_info':
						var_info = var_info + c;
						continue;
					default:
						console.log("SYNTAX ERROR AT POSITION ", i);
						console.log(validate_string.substring(i));
						continue;
				}
		}
	}

	console.log("SYNTAX ERROR: NO ) FOUND TO END WITH");
}


function auto_validate(obj, validate_string)
{
	var params = decode_validation_string (validate_string);

	var validation_errors = [];

	function fill_validation_object (obj, params)
	{
		var f_params = params;

		for (var i = 0; i < f_params.length; i++)
		{
			var p = f_params[i];
			var value_in_object = obj[p.name];
			if (p.data_type == 'o')
			{
				p.fields = fill_validation_object (value_in_object, p.fields);
			}
			else
			{
				p.original_value = value_in_object;

				if (typeof value_in_object == 'undefined')
				{
					if (p.optional == false)
					{
						p['error'] = p.name + ' is a required field';
						validation_errors.push(p['error']);
					}
					continue;
				}

				if (value_in_object == null)
				{
					if (p.nullable == false)
					{
						p['error'] = p.name + ' cannot be null';
						validation_errors.push(p['error']);
						p.valid = false;
						continue;
					}
					else
					{
						p.valid = true;
						p.value = null;
						continue;
					}
				}

				var str_value = value_in_object.toString();
				if (str_value == '' && p.empty_becomes_null == true)
				{
					p.value = null;
					p.valid = true;
					continue;
				}

				if (p.data_type == 'i')
				{
					if (str_value.match (/[0-9]*/) == null)
					{
						p.valid = false;
						p['error'] = p.name + ' must be a valid integer';
					}
					else
					{
						p.valid = true;
						p.value = parseInt(str_value);
					}
				}
				else if (p.data_type == 's')
				{
					p.valid = true;
					p.value = p.original_value;
					obj[p.name] = p.value;
				}
				else if (p.data_type == 'b')
				{
					if (str_value.match (/true|false|t|f/i) == null)
					{
						p.valid = false;
						p['error'] = p.name + ' must be a valid boolean (false, f, true or t)';
					}
					else
					{
						p.valid = true;
						if (str_value[0] == 'f' || str_value[0] == 'F')
							p.value = false;
						else
							p.value = true;

					}
				}
				else if (p.data_type == 'f')
				{
					if (str_value.match (/[0-9]*(\.[0-9]*)?/) == null)
					{
						p.valid = false;
						p['error'] = p.name + ' must be a valid numeric value';
					}
					else
					{
						p.valid = true;
						p.value = parseFloat(str_value);
					}
				}
				else if (p.data_type == 'd' || p.data_type == 't')
				{
					if (str_value.match (/[0-9]{1,2}(\/|-)[0-9]{1,2}(\/|-)[0-9]{4}/) != null)
					{
						p.valid = true;
						p.value = new Date(str_value);
					}
					else if (str_value.match (/[0-9]{4}(\/|-)[0-9]{1,2}(\/|-)[0-9]{1,2}/) != null)
					{
						p.valid = true;
						p.value = new Date(str_value);
					}
					else
					{

						p.valid = false;
					}
				}
				else if (p.data_type == 'a')
				{
					p.value = p.original_value;
					if (typeof original_value == 'object')
					{
						p.valid = true;
					}
					else
					{
						p.valid = false;
					}
				}
				else
				{
					p.valid = true;
					p.value = p.original_value;
				}

				obj[p.name] = p.value;
				if (p['error'])
					validation_errors.push(p['error']);

			}
		}

		return f_params;
	}

	var ret = fill_validation_object (obj, params);

	return {obj: ret, errors: validation_errors};
}

module.exports.validate = auto_validate;


