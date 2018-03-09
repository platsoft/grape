
// Session validator: check validity of session

const path = require('path');
const fs = require('fs');
const http_auth = require(__dirname + '/http_auth.js');


module.exports = function() {

	function set_session_from_result (session_result, req, res)
	{
		if (!session_result)
		{
			var session = {
				session_id: null,
				user_roles: ['guest']
			};
			req.session_id = null;
			req.session = session;
			res.locals.session = session;
		}
		else
		{
			if (!session_result.user_roles)
				session_result.user_roles = [];

			if (session_result.user_roles.indexOf('all') < 0)
				session_result.user_roles.push('all');
			
			req.session_id = session_result.session_id;
			req.session = session_result;
			res.locals.session = session_result;
		}
	}


	function check_session_id(session_id, req, res, next) {
		
		var ip_address = req.ip;

		req.app.get('grape').comms.session_lookup(session_id, function(err, result) {

			//console.log("Result from session lookup comms:", result);
			if (result)
			{
				set_session_from_result(result, req, res);
				next();
			}
			else
			{
				req.app.get('guest_db').query('SELECT grape.validate_session($1, $2, $3) x', [session_id, ip_address, req.headers], 
					function(err, result) {
						if (err)
						{
							var error_object = {
								'status': 'ERROR',
								'message': err.toString(),
								'code': -99,
								'error': err
							};
							res.jsonp(error_object).end();
							return;
						}

						var result = result.rows[0]['x'];

						set_session_from_result(result, req, res);

						if (result)
						{
							req.app.get('grape').comms.new_session(result.session_id, result);
						}

						next();
				});
			}
		});
		
	};

	return function(req, res, next) {
		var app = req.app;
		
		set_session_from_result(null, req, res);

		if (req.header('X-SessionID'))
		{
			check_session_id(req.header('X-SessionID'), req, res, next);
		}
		else if (req.header('Authorization'))
		{
			http_auth(req, res, next);
		}
		else if (req.header('Cookie'))
		{
			var cookies = {};
			req.header('Cookie').split(';').forEach(function(c) {
				c = c.trim();
				var ar = c.split('=');
				cookies[ar[0]] = ar[1];
			});

			if (cookies['session_id'])
			{
				check_session_id(cookies['session_id'], req, res, function() {
					if (!req.session.session_id)
						res.set('Set-Cookie', 'session_id=; path=/; HttpOnly');
					next();
				});
			}
			else
			{
				next();
			}
		}
		else
		{

			next();
		}
	};
};



