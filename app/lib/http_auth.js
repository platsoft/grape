
module.exports = function(req, res, next) {
	var app = req.app;
	var db = app.get('guest_db');

	// TODO error checking
	var authorization = req.header('Authorization');
	var ar = authorization.split(' ');
	if (ar[0] != 'Basic')
	{
		app.get('logger').error('Unsupported Authorization type');
		next();
	}

	var credentials = new Buffer(ar[1], 'base64').toString();
	ar = credentials.split(':');

	var obj = {
		username: ar[0],
		password: ar[1],
		ip_address: req.connection.remoteAddress,
		persistant: true
	};

	app.get('logger').session('debug', 'Using HTTP Authorization to acquire a Session ID');

	db.json_call('grape.session_insert', obj, function(err, result) {
		if (!err)
		{
			var obj = result.rows[0]['grapesession_insert'];
			if (obj.status == 'ERROR')
			{
				if (req.header('X-Requested-With') != 'XMLHttpRequest')
				{
					res.header('WWW-Authenticate', 'Basic realm="platsoft.net" charset=UTF-8');
					app.get('logger').warn('session', 'Authentication failed (' + obj.message + ')');
					if (req.accepts_json)
						res.status(401).json(obj);
					else
						res.status(401).send(obj);
				}
				else
				{
					res.status(403).send(obj);
				}
				
			}
			else
			{
				req.session_id = obj.session_id;
				res.locals.session = obj;
				next();
			}
		}
		else
		{
			app.get('logger').error('Error while creating session: ', err);
			res.json({error: err});
		}
		
	});

};


