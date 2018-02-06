
const ldapjs = require('ldapjs');

module.exports = function() {
	
	function get_service_ticket_from_auth_server (obj, serversettings, cb) {
		var ldapclient = ldapjs.createClient({
			url: serversettings.auth_server
		});

		ldapclient.bind('cn=root', serversettings.shared_secret, function(err) {
			if (err)
			{
				cb(err, null);
				return;
			}

			// service ticket request
			ldapclient.exop('8.1.2.2.3.11.22422.8.6.6', JSON.stringify(obj), function(err, value, res) {
				if (err)
				{
					cb(err, null);
					return;
				}
				var ret = JSON.parse(value);
				cb(null, ret);
				ldapclient.unbind();
			});

		});

	};

	function get_password_from_auth_server (obj, serversettings, cb) {
		
		var ldapclient = ldap.createClient({
			url: serversettings.auth_server
		});

		ldapclient.bind('cn=root', serversettings.shared_secret, function(err) {
			if (err)
			{
				cb(err, null);
				return;
				res.status(200).json({'status': 'ERROR', message: 'LDAP error', error: err});
				return;
			}

			var s_opts = {
				scope: 'base',
				filter: '',
				attributes: ['password']
			};

			if (obj.username)
				s_opts.filter = 'uid=' + obj.username;
			else if (obj.email)
				s_opts.filter = 'mail=' + obj.email;
			else
			{
				cb({message: 'No username or email defined to search for user with'}, null);
				return;
			}

			ldapclient.search(serversettings.auth_server_search_base, s_opts, function(err, result) {
				console.log(result);
				res.end();
				ldapclient.unbind();
			});


		});

	};

	return function(req, res) {
		var obj = {};
		
		if (req.body.email)
			obj.email = req.body.email;

		if (req.body.username)
			obj.username = req.body.username;

		res.locals.db.jsonb_call('grape.service_ticket_request', obj, function(err, result) {
			if (err)
			{
				res.json({status: 'ERROR', code: -99, error: err}).end();
				return;
			}

			var result = result.rows[0].result;

			console.log(result);

			if (result.status == 'ERROR' && result.code == -500) // need to get password from another server
			{
				var auth_server = result.auth_server;
				var auth_server_search_base = result.auth_server_search_base;
				res.locals.db.query('SELECT shared_secret FROM grape.service WHERE service_name=$1', [auth_server], function(err, result) {
					if (err || result.rows.length == 0)
					{
						res.json({status: 'ERROR', message: 'Unable to find secret for service ' + auth_server, error: err});
						return;
					}

					var shared_secret = result.rows[0].shared_secret;
					var serversettings = {
						auth_server: auth_server,
						shared_secret: shared_secret,
						auth_server_search_base: auth_server_search_base
					};

					get_tgt_from_auth_server(obj, serversettings, function(err, result) {
						if (err)
						{
							res.json({status: 'ERROR', message: err.message || 'LDAP error', error: err}).end();
							return;
						}
						// TODO what if we have to authenticate against LDAP instead
						res.json(result).end();
					});
				});

			}
			else
			{
				result.issued_by_url = 'local';
				res.json(result).end();
			}
		}, {alias: 'result'});
	};
};


