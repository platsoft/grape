
module.exports = function() {
	return function(req, res) {
		var ip_address = req.ip;

		if (typeof req.body.service_ticket == "undefined")
		{
			app.get('logger').session('info', 'invalid parameters sent to /grape/login_with_ticket', req.body);
			res.json({'status': "error", code: -1, "message": "invalid parameters"});
			return;
		}

		var obj = {
			service_ticket: req.body.service_ticket,
			issued_by: req.body.issued_by,
			ip_address: ip_address,
			headers: req.headers
		};

		if (req.body.otp)
			obj.otp = req.body.otp;

		res.locals.db.jsonb_call('grape.create_session_from_service_ticket', obj, function(err, result) {
			if (err)
			{
				res.json({
					status: 'ERROR',
					code: -99, 
					'message': err.toString(),
					'error': err
				}).end();
				return;
			}

			result = result.rows[0].grapecreate_session_from_service_ticket;
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

