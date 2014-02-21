
var grape = require('../');

var db = grape.db({dburi: 'tcp://postgres@localhost/postgres', debug: true});

var app = grape.app({
	api_directory: __dirname + '/api',
	db: db,
	port: 3001,
	public_directory: __dirname + '/public',
	debug: true
	
});

