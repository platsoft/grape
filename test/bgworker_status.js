
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var gc = new GrapeClient({url: 'http://localhost:3001/'});

gc.on('login', function() {
	console.log("Logged in");

	gc.getJSON('/grape/bgworker/status', {}, function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.login('admin', 'a');




