
var fs = require('fs');
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
var gc = new GrapeClient({url: 'http://localhost:' + config.port + '/', username: 'test', password: ''});

gc.on('login', function() {
	console.log("Logged in");

	gc.postJSON('/grape/bgworker/stop', {}, function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.login();



