
var fs = require('fs');
var util = require('util');

if (process.argv.length != 4)
{
	console.log("Usage: " + process.argv[0] + " " + process.argv[1] + " directory outputfile");
	process.exit(0);
	return;
}

var base_directory = process.argv[2];
var output_file = process.argv[3];


var ignore_directories = ['node_modules', 'public'];

var filetypes = [{type: 'Javascript', ext: 'js'}];

function debug(str)
{
	console.log('Debug: ', str);
}

var objects = {};

//extract values from a parameter string
//a parameter consists of a name, type, description, optionality indicator and default value
function extract_param_fields(raw)
{
	var param = raw;

	var ptype = '';
	var optional = 'required';
	var default_value = '';
	var pname = '';

	//look for the type 
	var matches = param.match(/\{?(integer|string|numeric|int|text|date|boolean|bool|object)\}?/i);
	if (matches)
	{
		ptype = matches[0];
		if (ptype[0] == '{' && ptype[ptype.length-1] == '}')
			ptype = ptype.substring(1, ptype.length-1);
		param = param.substring(0, matches.index).concat(param.substr(matches.index + matches[0].length));
	}

	matches = param.match(/optional|required/i);
	if (matches)
	{
		optional = matches[0];
		param = param.substring(0, matches.index).concat(param.substr(matches.index + matches[0].length));
	}

	matches = param.match(/default \S+/i);
	if (matches)
	{
		default_value = matches[0].substring(8);
		param = param.substring(0, matches.index).concat(param.substr(matches.index + matches[0].length));
	}
	
	param = param.trim();

	pname = param.substring(0, param.indexOf(' '));
	param = param.substring(pname.length).trim();
	
	if (pname == '')
		pname = param;
	
	return {name: pname, description: param, type: ptype, optional: optional, default_value: default_value, raw: raw};
}

function process_http_api_call(obj)
{
	if (typeof obj.tags['param'] != 'undefined')
	{
		if (!util.isArray(obj.tags['param']))
		{
			var a = obj.tags['param'];
			obj.tags['param'] = [a];
		}

		//a parameter consists of a name, type, description, optional indicator and default value
		var new_params = [];
		for (var i = 0; i < obj.tags['param'].length; i++)
		{
			new_params.push(extract_param_fields(obj.tags['param'][i]));
		}

		obj.tags['param'] = new_params;
	}
	

	if (typeof obj.tags['body'] != 'undefined')
	{
		var body = obj.tags['body'];

		var new_body = [];

		var toplevel = {children: []};
		var curr = toplevel;

		var tokens = body.split(/([\n,\{\}\[\]])/g);

		debug(tokens);

		for (var i = 0; i < tokens.length; i++)
		{
			var tok = tokens[i].trim();
			if (tok == '') 
				continue;
			if (tok == '[')
			{
				var n = {p: curr, type: 'array', children: []};
				curr.children.push(n);
				curr = n;
			}
			else if (tok == ']')
			{
				curr = curr.p;
			}
			else if (tok == '{')
			{
				var n = {p: curr, type: 'object', children: []};
				if (curr)
				{
					if (typeof curr.children == 'undefined')
						curr = {p: null, type: 'object', children: [curr]};
					curr.children.push(n);
				}
				curr = n;
			}
			else if (tok == '}')
			{
				curr = curr.p;
			}
			else if (tok == ',')
			{
			}
			else
			{
				if (curr)
					curr.children.push(extract_param_fields(tok));
				else
				{
					curr = extract_param_fields(tok);
				}
			}
		}

		function shiftChildren(obj)
		{
			var ret = [];
			if (typeof obj.children == 'undefined')
				return obj;

			for (var i = 0; i < obj.children.length; i++)
			{
				if (typeof obj.children[i].children == 'undefined')
					ret.push(obj.children[i]);
				else
					ret.push(shiftChildren(obj.children[i]));
			}
			return ret;
		}
		debug("toplevel before shift: " + util.inspect(toplevel));
		obj.tags['body'] = shiftChildren(toplevel);
		debug("after shift: " + util.inspect(obj.tags['body']));
	}
	
	if (typeof obj.tags['returnsample'] != 'undefined')
	{
		var json = JSON.parse(obj.tags['returnsample']);
		obj.tags['returnsample'] = JSON.stringify(json, null, "\t");
	}

	return obj;
}

function classifyObjectType(obj)
{
	//HTTP methods (aka API calls)
	var keys = Object.keys(obj.tags);
	debug(keys);
	if (keys.indexOf('url') >= 0 || keys.indexOf('api') >= 0)
	{
		obj.type = 'http_api_call';
		if (keys.indexOf('api') >= 0)
			obj.tags['url'] = obj.tags['api'];

		obj.identifier = obj.tags['url'];

		obj = process_http_api_call(obj);
	}
	else
	{
		debug("ERROR: COULD NOT IDENTIFY OBJECT");
	}

	return obj;
}

function processCommentBlock(block, current_file)
{
	debug('Block: ' + block);

	//var matches = block.match(/(@[a-z]+[\s\S]*?)(?=(@[a-z]+))/g);
	//var matches = block.match(/((@[a-z]+[\s\S]*?)(?=(@[a-z]+)))/g);
	var matches = block.match(/(\s@[a-z]+[\s\S]*?(?=(\s@[a-z]+)))|(\s@[a-z]+[\s\S]*?$)/g);
	
	if (matches == null)
		return;

	debug (matches);

	var current_object = {filename: current_file, type: null, identifier: '', tags: {}};

	for (var i = 0; i < matches.length; i++)
	{
		var line = matches[i];
		var line = line.replace(/^[\*\s]*/, '').replace(/[\s\*\/]*$/, '');
		line = line.replace(/[\s]*\*/g, '\n');

		// entities
		line = line.replace(/\</g, '&#x003C;');
		line = line.replace(/\>/g, '&#x003E;');
		line = line.replace(/\&/g, '&#x0026;');


		debug('Match: [' + line + ']');

		var ar = line.match(/^@[a-z]+/);
		var tag = ar[0].substring(1);
		var rest = line.substring(tag.length+1).trim();
		debug('Tag: ' + tag);
		debug('Rest: ' + rest);

		if (current_object.tags[tag])
		{
			debug("It exists");
			if (!util.isArray(current_object.tags[tag]))
			{
				var a = current_object.tags[tag];
				current_object.tags[tag] = [a];
			}
			current_object.tags[tag].push(rest);
		}
		else
		{
			current_object.tags[tag] = rest;
		}
	}

	current_object = classifyObjectType(current_object);

	if (current_object.type != null)
	{
		if (typeof objects[current_object.type] == 'undefined')
			objects[current_object.type] = [];
		objects[current_object.type].push(current_object);
	}
}

function processFile(path)
{
	var ar = path.split('.');
	var ext = ar[ar.length - 1];
	if (ext != 'js')
		return;
	debug('Processing file ' + path);
	
	var file_contents = fs.readFileSync(path, {encoding: 'utf8'});
	//var matches = file_contents.match(/\/\*\*[*]*\*\//gs);
	var matches = file_contents.match(/\/\*([\s\S]*?)\*\//g);

	if (!matches)
		return;

	for (var i = 0; i < matches.length; i++)
	{
		processCommentBlock(matches[i], path);
	}
}

function processDirectory(dirname)
{
	var ar = dirname.split('/');
	var basename = ar[ar.length - 1];
	if (ignore_directories.indexOf(basename) >= 0)
		return;
		
	var files = fs.readdirSync(dirname);


	debug('Reading directory ' + dirname);

	dirname = dirname.replace(/\/{2}/, '/').replace(/\/{2}/, '/');

	for (var i = 0; i < files.length; i++)
	{
		var file = files[i];
		
		debug('\tFile ' + file);

		if (file[0] == '.')
			continue;
		
		var stat = fs.statSync(dirname + '/' + file);
		if (stat.isDirectory())
		{
			processDirectory(dirname + '/' + file);
		}
		else if (stat.isFile())
		{
			processFile(dirname + '/' + file);
		}
	}


}

function createXML (elname, object) 
{
	debug(typeof object);
	if (typeof object == 'undefined')
		return 'undefined';

	var ret = new String();
	if (util.isArray(object))
	{
		debug("Processing array of length " + object.length);
		ret = '<' + elname + '>';
		for (var i = 0; i < object.length; i++)
		{
			debug("Item " + i + " is of type " + (typeof object[i]) + " with value " + object[i]);
			if (typeof object[i] == 'object'  || util.isArray(object[i]))
				ret = ret + createXML('item', object[i]);
			else
				ret = ret + '<' + elname + '>' + object[i] + '</' + elname + '>';
		}
		ret = ret + '</' + elname + '>';
	}
	else 
	{
		ret = '<' + elname + '>';
		var keys = Object.keys(object);
		for (var i = 0; i < keys.length; i++)
		{
			if (typeof object[keys[i]] == 'object' || util.isArray(object[keys[i]]))
				ret = ret + createXML(keys[i], object[keys[i]]);
			else
				ret = ret + '<' + keys[i] + '>' + object[keys[i]] + '</' + keys[i] + '>';
		}
		ret = ret + '</' + elname + '>';
	}
	return ret;
}



processDirectory(base_directory);

debug(util.inspect(objects, {depth: null}));

var newDoc = createXML('objects', objects);
fs.writeFileSync(output_file, newDoc);


