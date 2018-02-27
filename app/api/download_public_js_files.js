"use strict";
var db;
var app;
const syntax_check = require('syntax-error');
const fs = require('fs');
const path = require('path');

exports = module.exports = function(_app) {
	app = _app;
	db = app.get('db');

/**
 * @desc Return a compiled bundle of all JS files in public_directories named any one of compile_js_dirs
 * @method GET
 * @url /grape/api_list
 * @return Javascript
 **/
	app.get("/download_public_js_files", api_download_public_js_files);
};

// recursively concatenate all js files in dirname
function loadpublicjsfiles(dirname, relativedirname)
{
	var data = '';

	if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

	if (dirname[dirname.length - 1] != '/') dirname += '/';

	try {
		var files = fs.readdirSync(dirname);
	} catch (e) { 
		var files = []; 
	}

	for (var i = 0; i < files.length; i++)
	{
		var file = files[i];
		var fstat = fs.statSync(dirname + file);
		if (fstat.isFile())
		{
			var ar = file.split('.');
			if (ar[ar.length - 1] == 'js')
			{
				// loads the api module and execute the export function with the app param.
				data += '// JAVASCRIPT FILE ' + dirname + file + "\n";
				data += "var __FILENAME__ = '" + file + "';\n";
				data += "var __DIRNAME__ = '" + relativedirname + "';\n";
				data += "var __REALPATH__ = '" + dirname + "';\n";

				var file_data = fs.readFileSync(dirname + file);

				var check_error = syntax_check(file_data, dirname + file);
				if (check_error)
				{
					app.get('logger').error('app', "Syntax error in JS file " + relativedirname + file + " " + check_error);
					data += '/* JAVASCRIPT ERROR ' + check_error + ' */';
				}
				else
				{
					data += file_data;
					app.get('logger').info('app', "Loaded public JS file " + path.join(dirname, file));
				}
			}
		}
		else if (fstat.isDirectory())
		{
			data += loadpublicjsfiles(path.join(dirname, file), relativedirname + file);
		}
	}
	return data;
}


function api_download_public_js_files(req, res)
{
	// special API call will look in all public directories's subdir pages and download all .js files from there
	if (app.get('jsdata'))
	{
		var jsdata = app.get('jsdata');
	}
	else
	{
		var jsdata = [];
		var public_directories = app.get('config').public_directories;
		for (var i = 0; i < public_directories.length; i++)
		{
			app.get('config').compile_js_dirs.forEach(function(f) { 
				jsdata.push(loadpublicjsfiles(path.join(public_directories[i], f), '/' + f));
			});
		}

		if (app.get('config').cache_public_js_dirs)
			app.set('jsdata', jsdata);
	}

	res.set('Content-Type', 'application/javascript');
	res.send(jsdata.join(''));
}


