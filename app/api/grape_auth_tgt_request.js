
const ldapjs = require('ldapjs');

module.exports = function() {
	
	function get_tgt_from_auth_server (obj, serversettings, cb) {
		var ldapclient = ldapjs.createClient({
			url: serversettings.auth_server
		});

		ldapclient.bind('cn=root', serversettings.shared_secret, function(err) {
			if (err)
			{
				cb(err, null);
				return;
			}

			ldapclient.exop('8.1.2.2.3.11.22411.7.6.5', JSON.stringify(obj), function(err, value, res) {
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

	return function(req, res) {
		var obj = {};
		
		if (req.body.email)
			obj.email = req.body.email;

		if (req.body.username)
			obj.username = req.body.username;

		res.locals.db.jsonb_call('grape.TGT_request', obj, function(err, result) {
			if (err)
			{
				res.json({status: 'ERROR', code: -99, error: err}).end();
				return;
			}

			var result = result.rows[0].result;

			//console.log(result);

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


