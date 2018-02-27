
module.exports = function() {
	return function(req, res) {
		if ((typeof req.body.username == "undefined" && typeof req.body.email == "undefined") || typeof req.body.password == "undefined")
		{
			req.app.get('logger').session('info', 'invalid parameters sent to /grape/login', req.body);
			res.json({'status': "error", code: -1, "message": "invalid parameters"});
			return;
		}
		
		var ip_address = req.ip;

		var obj = {
			password: req.body.password,
			ip_address: ip_address,
			headers: req.headers
		};
		
		if (req.body.email)
		{
			obj.email = req.body.email;
			req.app.get('logger').session('info', 'login attempt from [', obj.email, ']@', ip_address);
		}
		else
		{
			obj.username = req.body.username;
			req.app.get('logger').session('info', 'login attempt from ', obj.username, '@', ip_address);
		}

		res.locals.db.json_call('grape.create_session_from_password', obj, function(err, result) {
			if (err || result.rows.length == 0)
			{
				res.json({status: 'ERROR', code: -99, error: err}).end();
				return;
			}

			result = result.rows[0].grapecreate_session_from_password;
			if (result.status == 'OK')
			{
				res.set('Set-Cookie', 'session_id=' + result.session_id + '; path=/; HttpOnly');
				res.json(result);
			}
			else
			{
				res.json(result);
			}
		});

	};
};

