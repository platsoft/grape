
module.exports = function() {
	return function(req, res) {
		if (!res.locals.session.session_id)
		{
			req.app.get('logger').warn('app', 'Security warning: Suspicious activity, user without access is trying to switch user');
			// end the connection silently - after waiting 1 second
			setTimeout(function () { res.end(); }, 1000);
			return;
		}
		
		var ip_address = req.ip;

		res.locals.db.jsonb_call('grape.switch_user', { 
			guid: req.body.guid, 
			username: req.body.username, 
			user_id: req.body.user_id ,
			ip_address: ip_address,
			http_headers: req.headers
		}, function(err, result) { 
			if (err || result.rows.length == 0)
			{
				res.json({
					status: 'ERROR',
					code: -99,
					error: err
				}).end();
				return;
			}
			var result = result.rows[0].grapeswitch_user;
				
			res.set('Set-Cookie', 'session_id=' + result.session_id + '; path=/; HttpOnly');

			res.json(result).end();
		});
	};
};
