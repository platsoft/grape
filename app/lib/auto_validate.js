/**
 * Validate string syntax (BNF):
 * 	obj-def ::= "(" <param-def-list> ")"
 * 	param-def-list ::= <param-def> | <param-def-list> "," <param-def>
 *	param-def ::= <param-name> ":" <type-info> <modifier-list>
 *	type-info ::= <array-def> | <data-type> | <obj-def>
 *	array-def ::= "[" <data-type> "]" | "[" <obj-def> "]"
 *	data-type ::= "s" | "i" | "f" | "b" | "d" | "t" | "a"
 *	modifier-list ::= <modifier> <modifier-list>
 *	modifier ::= "*" | "E" | "0" | ""
 *
 * Data types:
 * 	s text
 *	i integer
 * 	f float
 * 	b boolean
 * 	d date
 * 	t datetime
 *
 * Modifiers:
 *	* optional is true (default = false)
 *	E Empty becomes null
 *	0 Nullable
 *
 * Examples:
 *	(batch_labreport_id: i, product_id: i, labreport: [(product_id: i)]* )
 */
var DEBUG=0;


function decode_validation_string (validate_string)
{
//	if (DEBUG)
		//console.log("Decoding string {" + validate_string + "}");

	var fields = [];
	var i = 0;
	var state = '';
	var var_name = '';
	var var_info = '';
	var datatype_indicators = ['s', 'i', 'f', 'b', 'd', 't', 'a', 'j'];
	var current_object;

	function new_empty_object()
	{
		var obj = new Object({
			name: '',
			data_type: null,
			nullable: false,
			optional: false,
			empty_becomes_null: false,
			is_object: false,
			is_array: false,
			items: null  // object like this one (if this is an array), or an array with objects like this (if its an object)
		});
		return obj;
	}

	function save ()
	{
		fields.push(current_object);
		current_object = new_empty_object();
		return current_object;
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
					current_object = new_empty_object();
				}
				else if (state == 'var_info') //nested object'
				{
					var dec_result = decode_validation_string (validate_string.substring(i));
					i += dec_result.pos;
					current_object.items = dec_result.fields;
					current_object.is_object = true;
					current_object.data_type = 'object';
				}
				else if (state == 'array_def') // array with objects
				{
					var dec_result = decode_validation_string (validate_string.substring(i));
					i += dec_result.pos;
					current_object.items.is_object = true;
					current_object.items.data_type = 'object';
					current_object.items.items = dec_result.fields;
				}
				continue;
			case ':':
				//done with var_name, expecting variable info next
				state = 'var_info';
				var_info = '';
				current_object.name = var_name;
				continue;
			case ',':
				save();
				state = 'var_name';
				var_name = '';
				//we can save var_name and var_info now
				continue;
			case ')':
				save();
				if (DEBUG)
					console.log("Decoding ", validate_string, " Result: ", JSON.stringify(fields, null, '   '));
				return {fields: fields, pos: i};
			case '[':
				state = 'array_def';
				current_object.is_array = true;
				current_object.data_type = 'array';
				current_object.items = new_empty_object();
				continue;
			case ']':
				state = 'var_info';
				continue;
			default:
				switch (state)
				{
					case 'array_def':
						if (datatype_indicators.indexOf(c) >= 0)
						{
							current_object.items.data_type = c;
						}
						else
						{
							return {error: 'Syntax error at position ' + i + ': Expected a data type indicator inside an array'};
						}
						continue;
					case 'var_name':
						if (c == ' ' || c == '\n' || c == '\t' || c == '\r')
							continue;
						var_name = var_name + c;
						continue;
					case 'var_info':
						if (c == 'E')
						{
							current_object.empty_becomes_null = true;
						}
						else if (c == '*')
						{
							current_object.optional = true;
						}
						else if (c == '0')
						{
							current_object.nullable = true;
						}

						else if (datatype_indicators.indexOf(c) >= 0)
						{
							if (current_object.data_type)
							{
								console.log("WARNING: DATA TYPE IS ALREADY SET FOR VARIABLE " + var_name);
							}
							current_object.data_type = c;
						}
						continue;
					default:
						console.log("SYNTAX ERROR AT POSITION ", i);
						console.log(validate_string.substring(i));
						continue;
				}
		}
	}

	return {error: 'Syntax error: Unexpected end of input. No matching ) found'};
}

function validate_field(field, str_value)
{
	if (field.data_type == 'j') //json
	{
		try
		{
			field.value = JSON.parse(str_value);
			field.valid = true;
		}
		catch (e) {
			field.valid = false;
			field['error'] = field.name + ' must be valid json';
		}
	}
	else if (field.data_type == 'i') // integer
	{
		if (str_value.match (/^[0-9]+$/) == null)
		{
			field.valid = false;
			field['error'] = field.name + ' must be a valid integer';
		}
		else
		{
			field.valid = true;
			field.value = parseInt(str_value);
		}
	}
	else if (field.data_type == 's') // string
	{
		field.valid = true;
		field.value = field.original_value;
	}
	else if (field.data_type == 'b') // boolean
	{
		if (str_value.match (/true|false|t|f/i) == null)
		{
			field.valid = false;
			field['error'] = field.name + ' must be a valid boolean (false, f, true or t)';
		}
		else
		{
			field.valid = true;
			if (str_value[0] == 'f' || str_value[0] == 'F')
				field.value = false;
			else
				field.value = true;

		}
	}
	else if (field.data_type == 'f') // float
	{
		if (str_value.match (/^[0-9]*(\.[0-9]*)?$/) == null)
		{
			field.valid = false;
			field['error'] = field.name + ' must be a valid numeric value';
		}
		else
		{
			field.valid = true;
			field.value = parseFloat(str_value);
		}
	}
	else if (field.data_type == 'd' || field.data_type == 't') //date time
	{
		if (field.data_type == 'd')
		{
			// Non timezone-safe hack to avoid - vs / date parsing issues
			if (!str_value.endsWith('Z'))
				{ str_value = str_value + 'Z'; }
		}

		if (str_value.match (/^[0-9]{1,2}(\/|-)[0-9]{1,2}(\/|-)[0-9]{4}/) != null)
		{
			field.valid = true;
			field.value = new Date(str_value);
		}
		else if (str_value.match (/^[0-9]{4}(\/|-)[0-9]{1,2}(\/|-)[0-9]{1,2}/) != null)
		{
			field.valid = true;
			field.value = new Date(str_value);
		}
		else
		{
			field.valid = false;
		}
	}
	else if (field.data_type == 'a')
	{
		field.value = field.original_value;
		if (typeof field.original_value == 'object')
		{
			field.valid = true;
		}
		else
		{
			field.valid = false;
		}
	}
	else
	{
		field.valid = true;
		field.value = field.original_value;
	}

}


//params is an array with validation parameters (as returned from decode_validation_string)
//obj is the object we are validating
function validate_object (obj, params)
{
	var f_params = params;
	var errors = [];

	for (var i = 0; i < f_params.length; i++)
	{
		var p = f_params[i];
		p.original_value = null;
		p.value = null;
		p.valid = false;
		p.errors = [];

		var value_in_object = obj[p.name];

		p.original_value = value_in_object;

		if (typeof value_in_object == 'undefined')
		{
			if (p.optional == false)
			{
				p.errors.push(p.name + ' is a required field');
				errors.push('Required field "' + p.name + '" is missing');
				continue;
			}
			else
			{
				p.valid = true;
				p.value = undefined;
				if (p.empty_becomes_null)
					obj[p.name] = null;
				continue;
			}
		}


		if (p.is_object)
		{
			if (typeof value_in_object != 'object')
			{
				p.valid = false;
				p.errors.push(p.name + ' is supposed to be an object');
				errors.push('The field "' + p.name + '" is supposed to be an object');
			}

			var validate_ret = validate_object(value_in_object, p.items);
			if (validate_ret.errors.length > 0)
			{
				validate_ret.errors.forEach(function(e) {
					errors.push(['Error in "', p.name, '": ', e].join(''));
					p.errors.push(e);
				});
				p.value = null;
			}
			else
			{
				p.value = p.original_value;
			}
			p.items.items = validate_ret.fields;
		}
		else if (p.is_array)
		{
			if (Array.isArray(value_in_object))
			{
				var found_error = false;
				var new_items = [];

				if (p.items.is_object) // array of objects
				{
					for (var j = 0; j < value_in_object.length; j++)
					{
						if (typeof value_in_object[j] == 'object')
						{
							var validate_result = validate_object(value_in_object[j], p.items.items);
							if (validate_result.errors.length == 0)
							{
								new_items.push(validate_result.fields);
							}
							else
							{
								p.valid = false;
								validate_result.errors.forEach(function(e) {
									var err = 'Error in array item #' + j + ' in "' + p.name + '": ' + e;
									errors.push(err);
									p.errors.push(err);
								});
							}
						}
						else
						{
							p.valid = false;
							var err = 'Array item #' + j + ' in "' + p.name + '" is supposed to be an object';
							p.errors.push(err);
							errors.push(err);
						}
					}

					p.valid = true;
				}
				else // array of simple values
				{
					for (var j = 0; j < value_in_object.length; j++)
					{
						var field = new Object(p.items);
						field.original_value = value_in_object[j];
						validate_field(field, value_in_object[j].toString());
						if (field.valid)
						{
							new_items.push(field.value);
						}
						else
						{
							p.valid = false;
							p['error'] = 'Error in "' + p.name + '" array item #' + j + ': ' + field.error;
							errors.push(p['error']);

							break;
						}
					}
					p.value = new_items;
				}
			}
			else
			{
				p.valid = false;
				var err = p.name + ' is supposed to be an array';
				p.errors.push(err);
				errors.push('The field ' + p.name + ' is supposed to be an array');
			}
		}
		else
		{


			if (value_in_object !== null)
			{
				var str_value = value_in_object.toString();
				if (str_value == '' && p.empty_becomes_null == true)
				{
					value_in_object = null;
				}
			}

			if (value_in_object == null)
			{
				if (p.nullable == false)
				{
					p.errors.push('"' + p.name + '" cannot be null');
					errors.push(p['error']);
					p.valid = false;
					continue;
				}
				else
				{
					p.valid = true;
					p.value = null;

					if (p.empty_becomes_null)
						obj[p.name] = null;
					continue;
				}
			}
			else
			{
				validate_field(p, str_value);

				obj[p.name] = p.value;
				if (p['error'])
					errors.push(p['error']);

			}
		}
	}

	return {fields: f_params, errors: errors};
}


function auto_validate(obj, validate_string)
{
	var dec_result = decode_validation_string (validate_string);
	if (dec_result.error)
		return {obj: null, errors: ['Decoding error', dec_result.error]};
	var validate_res = validate_object(obj, dec_result.fields);

	return {obj: validate_res.fields, errors: validate_res.errors};
}

module.exports.validate = auto_validate;


