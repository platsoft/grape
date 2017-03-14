
var fs = require('fs');
var util = require('util');
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
var gc = new GrapeClient({url: 'http://localhost:' + config.port + '/', username: 'test', password: ''});

gc.on('login', function() {
	console.log("Logged in");

	gc.getJSON('/simple_get_call/10', {}, function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.on('error', function(err) {
	console.log("Error: " + util.inspect(err));
});

gc.login();


