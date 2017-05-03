
var commander = require('commander');

commander
	.version('0.0.1')
	.option('-p, --peppers', 'Add peppers')
	.option('-c, --cheese [type]', 'Add the specified type of cheese [marble]', 'marble')
	.option('-l, --list <list>', 'A list of stuff', ['a', 'b'])
	.parse(process.argv);

if (commander.peppers)
	console.log("PEPPERS");

if (commander.cheese)
	console.log("CHEESE: " + commander.cheese);

if (commander.list)
	console.log("LIST: " + commander.list);

