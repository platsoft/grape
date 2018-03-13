var parse_connection_string = require('pg-connection-string').parse;
var util = require('util');
var GrapeCmd = {};

GrapeCmd.info = {
	description: 'Print database settings in a format usable by bash scripts',
	db: false
};

// opts will contain: db, argv
GrapeCmd.run = function(opts, cb) {

	var dburi = opts.options.dburi;

	if (util.isString(dburi))
	{
		dburi = parse_connection_string(dburi);
	}

	console.log("PGDATABASE=" + dburi.database);
	console.log("PGHOST=" + dburi.host);
	if (dburi.port)
		console.log("PGPORT=" + dburi.port);
	console.log("PGUSER=" + dburi.user);
	
	cb(null);
};

module.exports = GrapeCmd;

