
var fs = require('fs');
var util = require('util');
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
var gc = new GrapeClient({url: 'http://localhost:' + config.port + '/', username: 'test', password: ''});

gc.on('login', function() {
	console.log("Logged in");

	gc.postJSON('/grape/user/save', {username: "hans3", password: "abc", "role_names": "admin"}, function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.on('error', function(err) {
	console.log("Error: " + util.inspect(err));
});

gc.login();


