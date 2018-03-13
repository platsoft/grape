

var configreader = require('../app/lib/configreader.js');

var options = configreader({session_management: false}, {session_management: true});

console.log(options);

