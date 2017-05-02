var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');

var gc = new GrapeClient({url: 'http://localhost:3003/'});

gc.on('login', function() {
        console.log("Logged in");

	gc.uploadFile('/grape/data_import/upload', {processing_function: 'dimport_suppliers'}, [{'file': 'upload_test.xlsx', 'fieldname': 'file_name'}], function(d) {
		console.log(d);
		gc.logout();
	});

});

gc.login('admin', 'admin');

