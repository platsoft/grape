
// Session validator, check permissions and validity of session
//

const path = require('path');
const fs = require('fs');
const http_auth = require(__dirname + '/http_auth.js');


module.exports = function() {

	function handle_session_check_result (result)
	{

	}


	function check_session_id(session_id, req, res, next) {
		
		var ip_address = req.ip;

		// XXX check cache first
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
				if (!result)
				{
					var session = {
						session_id: null,
						user_roles: ['guest']
					};
					res.set('Set-Cookie', 'session_id=; path=/; HttpOnly');
					req.session_id = null;
					req.session = session;
					res.locals.session = session;
				}
				else
				{
					if (result.user_roles.indexOf('all') < 0)
						result.user_roles.push('all');
					
					req.session_id = session_id;
					req.session = result;
					res.locals.session = result;
				}
	
				next();
		});
		
	};

	return function(req, res, next) {
		var app = req.app;
		
		var session = {
			session_id: null,
			user_roles: ['guest']
		};
		req.session_id = null;
		req.session = session;
		res.locals.session = session;


		console.log("CHECKING SESSION");

		if (req.header('X-SessionID'))
		{
			console.log("FOUND HEADER X-SESSION-ID");
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
				check_session_id(cookies['session_id'], req, res, next);
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



