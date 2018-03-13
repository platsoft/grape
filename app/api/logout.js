module.exports = function() {
	return function(req, res) {
		res.set('Set-Cookie', 'session_id=; expiry=0; path=/; HttpOnly');
		req.db.json_call('grape.logout', {session_id: req.query.session_id || req.session_id}, null, {response: res});

	};
};
