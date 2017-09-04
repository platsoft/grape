

var ldap = require('ldapjs');

function LDAPServer(options)
{
	var self = this;
	this.self = self;
	this.db = null;
	var grapelib = require(__dirname + '/../index.js');
	this.options = options;
	this.logger = new grapelib.logger(this.options);

	this.setup_db = function() {
		var _db = require(__dirname + '/db.js');
		var db = new _db({
			dburi: self.options.dburi,
			debug: self.options.debug,
			session_id: 'grape_ldap_server'
		});

		db.on('error', function(err) {
			self.logger.log('db', 'error', err);
		});

		db.on('debug', function(msg) {
			self.logger.log('db', 'debug', msg);
		});

		db.on('end', function() {
			self.logger.log('db', 'info', 'Database disconnected. Restarting');
			db.connect();
		});

		self.db = db;
	};

	this.authenticate_user = function(dn, password, cb) {
		var dn = dn.toString().replace(/, /g, ',');
		console.log(dn);
		self.db.query('SELECT grape.ldap_check_credentials($1, $2, $3)', [dn, password, ''], function(err, result) {
			if (err)
			{
				cb(err);
				return;
			}

			var result_code = result.rows[0].ldap_check_credentials;
			console.log("result code: " + result_code);
			cb(null, result_code);
		});
	};

	this.search_user = function(dn) {

	};

	this.start = function() {

		self.setup_db();

		var server = ldap.createServer({
			//certificate: self.options.sslcert,
			//key: self.options.sslkey
		});

		server.search('o=platsoft,ou=Users', function(req, res, next) {

			console.log("Search: ");
			console.log("DN: " + req.dn.toString());
			console.log("Filter: " + req.filter);

			var obj = {
				dn: 'uid=HansL,ou=Users,o=platsoft',
				attributes: {
					uid: 'HansL',
					cn: 'HansL',
					mail: 'hans@platsoft.net',
					employee_guid: 'b8d853a6-b579-6c3c-eb5d-4773ea245621'
				}
			};

			if (req.filter.matches(obj.attributes))
			{
				console.log("SENDING " + obj.dn.toString());
				res.send(obj);
			}

			res.end();
		});

		// req.connection.ldap
		// req.connection.ldap.bindDN

		server.bind('ou=Users,o=platsoft', function(req, res, next) {

			var ret = self.authenticate_user(req.dn, req.credentials, function(err, return_code) {
				
				switch (return_code)
				{
					case 0:
						res.end();
						return next();
						break;
					case -1:
						return next(new ldap.NoSuchObjectError());
						break;
					case -5:
						return next(new ldap.InvalidCredentialsError());
						break;
					default:
						return next(new ldap.OtherError());
				}

			});

		});

		server.add('ou=Users,o=platsoft', function(req, res, next) {
			console.log('Add new user to ' + req.dn.toString() + ': ' + req.toObject().attributes);
			res.end();
			return next();
		});

		server.bind('cn=root', function(req, res, next) {
			console.log("BIND cn=root");
			if (req.dn.toString() !== 'cn=root' || req.credentials !== 'secret')
				return next(new ldap.InvalidCredentialsError());
			res.end();
			return next();
		});

		server.listen(self.options.ldap_server_port, function() {
			  console.log('LDAP server listening at %s', server.url);
		});
	}
}

module.exports.LDAPServer = LDAPServer;

