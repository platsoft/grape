
var Grape = require('ps-grape');

var app = new Grape.grape("includes.json", "defaults.json", "locals.json"); 



app.start();

app.on('worker-httplistener', function(app) {
	// new express app created
});

