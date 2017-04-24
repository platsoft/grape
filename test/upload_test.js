var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var gc = new GrapeClient({url: 'http://localhost:3001/'});

gc.on('login', function() {
        console.log("Logged in");

	gc.uploadFile('/grape/data_upload', {}, [{'file': 'upload_test.xlsx', 'field': 'file'}], function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.login('admin', 'admin');

