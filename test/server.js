
var Grape = require(__dirname + '/../index.js');

var fs = require('fs');

var json_config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));

var config = {
	dburi: json_config.dburi,
	port: json_config.port,
	debug: true,
	public_directory: __dirname + '/public',
	session_management: true,
	email_template_directory: __dirname + '/email_templates'
};

if (json_config.smtp)
	config.smtp = json_config.smtp;

var app = new Grape.grape(config); 

app.start();


