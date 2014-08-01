
var httppost = require('./http-post');
var util = require('util');
var url = require('url');

if (process.argv.length != 4)
{
	console.log(util.format("Usage: URL File"));
	process.exit(1);
	return;
}

var options = url.parse(process.argv[2]);
var filename = process.argv[3];

options.headers = {'Accept': 'application/json; charset=utf-8'};

var req = httppost(options,
	{
		sale_type: 'IPS4Life'
	}, 

	[{param: 'batch_file', path: filename}], 

	function(responce) {

		//console.log(responce);
		var req = responce;
		req.on('end', function() {
			console.log("END");
		});

		req.on('data', function(data) {
			console.log("DATAAAA");
			//console.log(data);
		});


		req.on('error', function(err) {
			console.log("EROR GAAAR");
			console.log(err);
		});

	}
);


