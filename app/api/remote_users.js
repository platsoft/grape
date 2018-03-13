"use strict";
const ldapjs = require('ldapjs');

exports = module.exports = function() {


	return function (req, res)
	{
		var auth_server = req.body.auth_server;
		var shared_key = req.body.shared_key;
		var search_base = req.body.search_base;

		console.log(req.body);

		if (!auth_server)
		{
			res.json(200).status({'status': 'ERROR', message: 'Missing field auth_server'});
			return;
		}
		if (!shared_key)
		{
			res.json(200).status({'status': 'ERROR', message: 'Missing field shared_key'});
			return;
		}
		if (!search_base)
		{
			res.json(200).status({'status': 'ERROR', message: 'Missing field search_base'});
			return;
		}
		
		var client = ldapjs.createClient({
			url: auth_server,
			tlsOptions: {}
		});

		client.bind('cn=root', shared_key, function(err) {
			if (err)
			{
				res.json({status: 'ERROR', error: err}).end();
				return;
			}
		
			client.search(search_base, {
				scope: 'base',
				filter: '(uid=' + req.body.search_text + ')',
				sizeLimit: 50
			}, function(err, ldapres) {
				if (err)
				{
					res.json({status: 'ERROR', error: err}).end();
					return;
				}
				
				var all_results = [];

				ldapres.on('searchEntry', function(entry) {
					var obj = {
						dn: entry.objectName,
						attributes: []
					};

					all_results.push(entry.object);
				});

				ldapres.on('searchReference', function(referral) {
					// TODO what's this?
					console.log("LDAP SEARCH REFERENCE " , referral);
				});

				ldapres.on('error', function(err) {
					res.json({status: 'ERROR', error: err}).end();
				});

				ldapres.on('end', function(result) {
					res.json({status: 'OK', results: all_results}).end();
				});
			});

		});

	};

}

