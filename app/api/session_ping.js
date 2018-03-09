module.exports = function() {
	return function(req, res) {
		req.db.json_call('grape.session_ping', {}, function(err, result) {
			if (err || !result.rows)
			{
				res.set('Set-Cookie', 'session_id=; path=/; HttpOnly');
				var error_object = {
					'status': 'ERROR',
					'message': err.toString(),
					'code': -99,
					'error': err
				};

				res.jsonp(error_object);
				return;
			}
			var results = result.rows[0].grapesession_ping;
			if (results.status == 'ERROR')
				res.set('Set-Cookie', 'session_id=; path=/; HttpOnly');

			res.json(results).end();
		});
	};
};
