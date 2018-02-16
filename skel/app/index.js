
var Grape = require('ps-grape');

var app = new Grape.grape(
	"../config/includes.json", 
	"../config/defaults.json", 
	"../config/local.json"); 

// Register custom workers here

app.start();

app.on('worker-httplistener', function(app) {
	// new express app created
});

