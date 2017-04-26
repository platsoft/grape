
var fs = require('fs');
var util = require('util');
//var GrapeClient = require('ps-grape').grapeclient;
var GrapeClient = require('../app').grapeclient;
var url = require('url');


if (process.argv.length != 3)
{
	console.log("Usage: js_client.js URI\n\tWhere URI is a connection string, e.g. http://user:password@localhost:3003/");
	process.exit(0);
}

obj = url.parse(process.argv[2]);
var config = {
	url: [obj.protocol, '//', obj.host, '/'].join(''),
	username: '',
	password: ''};

var ar = obj.auth.split(':');
config.username = ar[0];

if (ar.length == 1)
	config.password = '';
else
	config.password = ar[1];

console.log(config);

var gc = new GrapeClient({url: config.url, username: config.username, password: config.password});

gc.on('login', function() {
	console.log("Logged in");

	// Put your API calls here
	
	gc.getJSON('/grape/bgworker/status', {}, function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.on('error', function(err) {
	console.log("Error: " + util.inspect(err));
});

gc.login();


