
var program = require('commander');

program
	.version('0.0.1')
	.option('-p, --peppers', 'Add peppers')
	.option('-c, --cheese [type]', 'Add the specified type of cheese [marble]', 'marble')
	.option('-l, --list <list>', 'A list of stuff', ['a', 'b'])
	.parse(process.argv);

if (program.peppers)
	console.log("PEPPERS");

if (program.cheese)
	console.log("CHEESE: " + program.cheese);

if (program.list)
	console.log("LIST: " + program.list);

