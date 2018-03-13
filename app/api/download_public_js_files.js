"use strict";
var db;
var app;
const syntax_check = require('syntax-error');
const fs = require('fs');
const path = require('path');

module.exports = function() {

	var app;

	function read_directory_permissions(dirname, dir_config)
	{
		var new_dir_config = dir_config;
		try {
			// TODO try everything in app.options.diroptions_filenames
			var read_dir_config = fs.readFileSync(path.join(dirname, 'directory.json'));
		} catch (e) {
		}
		return new_dir_config;
	}

	// recursively concatenate all js files in dirname
	function loadpublicjsfiles(dirname, relativedirname, user_roles, dir_config)
	{
		var data = '';

		if (!dir_config)
			var dir_config = {};

		if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

		if (dirname[dirname.length - 1] != '/') dirname += '/';

		try {
			var files = fs.readdirSync(dirname);
		} catch (e) { 
			var files = []; 
		}

		var new_dir_config = read_directory_permissions(dirname, dir_config);

		for (var i = 0; i < files.length; i++)
		{
			var file = files[i];
			var fstat = fs.statSync(path.join(dirname, file));
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

					var file_data = fs.readFileSync(path.join(dirname, file));

					var check_error = syntax_check(file_data, dirname + file);
					if (check_error)
					{
						app.get('logger').error('app', "Syntax error in JS file " + relativedirname + file + " " + check_error);
						data += '/* JAVASCRIPT ERROR ' + check_error + ' */';
					}
					else
					{
						data += file_data;
						app.get('logger').debug('app', "Loaded public JS file " + path.join(dirname, file));
					}
				}
			}
			else if (fstat.isDirectory())
			{
				data += loadpublicjsfiles(path.join(dirname, file), relativedirname + file, user_roles, dir_config);
			}
		}
		return data;
	}

	return function(req, res) {
		app = req.app;

		var user_roles = res.locals.session.user_roles;
		var str = user_roles.sort().join(',');

		// special API call will look in all public directories's subdir pages and download all .js files from there
		if (app.get('jsdata-' + str))
		{
			var jsdata = app.get('jsdata' + str);
		}
		else
		{
			var jsdata = [];
			var public_directories = app.get('config').public_directories;
			for (var i = 0; i < public_directories.length; i++)
			{
				var dirconf = {};

				app.get('config').compile_js_dirs.forEach(function(f) { 
					var data = loadpublicjsfiles(path.join(public_directories[i], f), '/' + f, user_roles, dirconf);
					jsdata.push(data);
				});
			}

			if (app.get('config').cache_public_js_dirs)
				app.set('jsdata-' + str, jsdata);
		}

		res.set('Content-Type', 'application/javascript');
		res.send(jsdata.join(''));
	}
};


