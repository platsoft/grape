#!/usr/bin/env node

var method = process.argv[2];
var url = process.argv[3];

if (process.argv[4])
	var data = JSON.parse(process.argv[4]) || {};
else
	var data = {};

function usage()
{
	console.log("Usage: grape-query GET|POST URL [json]");
	console.log("");
	console.log("\t URL must be in the format  http[s]://username:password@host:port/path");
	process.exit(1);
}

if (process.argv.length < 3)
{
	usage();
}

var grapeclient = require(__dirname + '/../index.js').grapeclient;

var GC = new grapeclient({url: url});

if (method == 'GET')
{
	var req = GC.getJSON(null, data, function(ret) {
		console.log(JSON.stringify(ret, null, '  '));

		//console.log(req.res.headers);
	});
}
else if (method == 'POST')
{
	GC.postJSON(null, data, function(ret) {
		console.log(JSON.stringify(ret, null, '  '));
	});

}
else
{
	usage();
}

