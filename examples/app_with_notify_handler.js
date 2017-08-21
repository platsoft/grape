
var Grape = require('ps-grape');
var cluster = require('cluster');

var config = require(__dirname + '/config.js');

if (cluster.isMaster)
{
	var db = new Grape.db({dburi: config.dburi, session_id: 'Custom notification listener'});
	db.on('error', function() { });
	db.on('debug', function() { });
	db.on('end', function() { });

	db.new_notify_handler('test123', function(d) {
		console.log(d);
	});
}

var app = new Grape.grape(config); 

app.start();


