var fs = require('fs');
var pg = require('pg');

exports = module.exports = function(option) {

	function loadsqlfiles(dirname, relativedirname, sql_list) 
		{
		if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

		if (dirname[dirname.length - 1] != '/') dirname += '/';

		var dir_list = [];
		var files = fs.readdirSync(dirname);
		for (var i = 0; i < files.length; i++) 
		{
			var file = files[i];
			var fstat = fs.statSync(dirname + file);
			if (fstat.isFile()) 
			{
				var ar = file.split('.');
				if (ar[ar.length - 1] == 'sql') 
				{
					sql_list.push({ 
						data: fs.readFileSync(dirname + file, 'utf8'),
						filename: dirname + file
					});
				}
			}
			else if (fstat.isDirectory()) 
			{
				dir_list.push(dirname + '/' + file);
			}
		}
		if (dir_list.length != 0) {
			var current_dir = dir_list.shift();
			while (current_dir)
			{
				loadsqlfiles(current_dir, relativedirname + file, sql_list);
				current_dir = dir_list.shift();
			}
		}
	}
	
	var schema_dir = option.schema_dir || option.schema_directory;
	var schema_list = [];
	if (schema_dir) 
	{
		loadsqlfiles(schema_dir, '', schema_list);
	};
	var data_dir = option.data_dir || option.data_directory;
	var data_list = [];
	if (data_dir) 
	{
		loadsqlfiles(data_dir, '', data_list);
	};
	var function_dir = option.function_dir || option.function_directory;
	var function_list = [];
	if (function_dir) 
	{
		loadsqlfiles(function_dir, '', function_list);
	};
	var sql_list = schema_list.concat(data_list, function_list);

	var Client = pg.Client;
	var client = new Client(option.config);
	client.connect();
	
	function rollback(client) {
		client.query('ROLLBACK', function() {
			client.end();
		});
	};

	client.query('BEGIN', function(err, result) {
		if (err) return rollback(client);
		var sql = sql_list.shift();
		function query_cb(err, result) {
			if (err) 
			{
				console.log(sql.filename);
				console.log(err);
				return rollback(client);
			};
			sql = sql_list.shift();
			if (sql) 
			{
				client.query(sql.data, query_cb);
			} else 
			{
				client.query('COMMIT', client.end.bind(client));
			}
		};
		client.query(sql.data, query_cb); 
	});
}
