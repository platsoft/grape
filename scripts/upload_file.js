
var GrapeClient = require(__dirname + '/../app/lib/grapeclient.js');
var program = require('commander');

program
	.version('0.0.1')
	.usage('-u username -p password -s server -f file -t filetype')
	.option('-u, --username [username]', 'Username')
	.option('-p, --password [password]', 'Password')
	.option('-s, --server [server]', 'Server (for example http://localhost:3000/)')
	.option('-f, --file [file]', 'File to upload')
	.option('-t, --file_type [file_type]', 'File type (The grape processing function name)')
	.option('-P, --process', 'Process the file after upload')
	.parse(process.argv);

if (!program.username || !program.password || !program.server || !program.file || !program.file_type)
{
	console.log("You need to specify a username, password, server, file and file type");
	program.help();
	process.exit(1);
}

var gc = new GrapeClient({url: program.server});

gc.on('login', function() {
        console.log("Logged in");

	gc.uploadFile('/grape/data_import/upload', {processing_function: program.file_type}, [{'file': program.file, 'fieldname': 'file_name'}], function(d) {
		console.log(d);
		if (d.status == 'OK')
		{
			console.log("Upload successful");
			
			if (program.process)
			{
				console.log("Processing " + d.data_import_id[0]);
				gc.postJSON('/grape/data_import/process', {data_import_id: d.data_import_id[0]}, function(d) {
					console.log(d);
					gc.logout();
				});
			}
			else
			{
				gc.logout();
			}
		}
		else
		{
			gc.logout();
		}
	});

});

gc.login(program.username, program.password);


