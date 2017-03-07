
var Grape = require(__dirname + '/../index.js');

var fs = require('fs');

var json_config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));

var config = {
	dburi: json_config.dburi,
	port: json_config.port,
	debug: true,
	public_directory: __dirname + '/public',
	session_management: true
};

var app = new Grape.grape(config); 

app.start();


