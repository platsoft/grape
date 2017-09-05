
var commander = require('commander');
var GrapeCmd = {};
	

GrapeCmd.info = {
	description: 'Lists all users in the system',
	db: true
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {

};

module.exports = GrapeCmd;

