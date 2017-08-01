// Express handler
// 

var util = require('util');

module.exports = function (req, res, next) {
	if (!res.locals.db)
	{
		next();
		return;
	}

	if (!req.headers['x-notifications'])
	{
		next();
		return;
	}

	res.locals.db.query('SELECT * FROM grape.check_notifications()', [], function(err, result) {
		if (err || !result.rows)
		{
			app.get('logger').error('app', 'Notification subsystem error');
			next();
		}

		var row = result.rows[0];
		var notifications = row.check_notifications;

		res.append('X-Notifications', new Buffer(JSON.stringify(notifications)).toString('base64'));

		next();
	});
};


