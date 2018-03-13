
const ldapjs = require('ldapjs');

module.exports = function() {
	
	function request_service_ticket_locally (req, res, obj)
	{
		res.locals.db.jsonb_call('grape.service_ticket_request', obj, null, {response: res});
	}

	function request_service_ticket_remotely (req, res, obj, auth_server_info)
	{
		var ldapclient = ldapjs.createClient({
			url: auth_server_info.auth_server
		});

		ldapclient.bind('cn=root', auth_server_info.auth_server_secret, function(err) {
			if (err)
			{
				res.json({status: 'ERROR', code: -88, error: err}).end();
				return;
			}

			// service ticket request
			ldapclient.exop('8.1.2.2.3.11.22422.8.6.6', JSON.stringify(obj), function(err, value, response) {
				if (err)
				{
					res.json({status: 'ERROR', code: -88, error: err}).end();
					return;
				}
				var ret = JSON.parse(value);
				ldapclient.unbind();
				res.json(ret).end();
			});

		});
	}

	return function(req, res) {
		var obj = {};
		var user_obj = {};
		
		if (req.body.email)
		{
			obj.email = req.body.email;
			user_obj.email = req.body.email;
		}

		if (req.body.username)
		{
			obj.username = req.body.username;
			user_obj.username = req.body.username;
		}


		obj.tgt = req.body.tgt;
		obj.authenticator = req.body.authenticator;
		obj.requested_service = req.body.requested_service;
		obj.tgt_issued_by = req.body.tgt_issued_by;
		obj.iv = req.body.iv;
		obj.salt = req.body.salt;

		if (obj.requested_service != obj.tgt_issued_by)
		{
			res.locals.db.jsonb_call('grape.get_user_auth_server_info', user_obj, function(err, result) {
				if (err)
				{
					res.json({status: 'ERROR', code: -99, error: err}).end();
					return;
				}

				var result = result.rows[0].result;
				if (!result.auth_server || result.auth_server == 'local')
				{
					request_service_ticket_locally(req, res, obj);
				}
				else
				{
					request_service_ticket_remotely(req, res, obj, result);
				}
			}, {alias: 'result'});
		}
		else
		{
			request_service_ticket_locally(req, res, obj);
		}
	};
};


