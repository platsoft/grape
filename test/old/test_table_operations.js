
var fs = require('fs');
var util = require('util');
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
var gc = new GrapeClient({url: 'http://localhost:' + config.port + '/', username: 'test', password: ''});

gc.on('login', function() {
	console.log("Logged in");

	gc.postJSON('/grape/insert_record', {schema: 'grape', tablename: 'user', values: {"username":"Piet","password":"aaa"}, "returning": "*"}, function(d) {
		console.log(d);

		gc.postJSON('/grape/update_record', {schema: 'grape', tablename: 'user', filter: {"username": "Piet"}, values: {"password":"abcdefg"}, "returning": "*"}, function(d) {
			console.log(d);
			gc.postJSON('/grape/delete_record', {schema: 'grape', tablename: 'user', filter: {"password":"abcdefg"}}, function(d) {
				console.log(d);
				gc.logout();
			});

		});


	});

});

gc.on('error', function(err) {
	console.log("Error: " + util.inspect(err));
});

gc.login();


