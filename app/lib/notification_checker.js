// Express handler
// 

var util = require('util');

function check_notifications(req, res, next) 
{

	res.locals.db.query('SELECT * FROM grape.check_notifications()', [], function(err, result) {
		if (err)
		{
			req.app.get('logger').error('app', 'Notification subsystem error');
			next();
			return;
		}

		if (!result.rows)
		{
			next();
			return;
		}

		var row = result.rows[0];
		var notifications = row.check_notifications;

		res.append('X-Notifications', new Buffer(JSON.stringify(notifications)).toString('base64'));
	
		var cache = req.app.get('cache');
		//console.log("CACHE?" + req.session_id);
		if (cache && req.session_id)
		{
			var cachename = [req.session_id, 'last_notification_check'].join('-');
			
			var now = parseInt((new Date()).getTime() / 1000);
			cache.set(cachename, now);
			//console.log("SETTING CACHE TO " + now);
		}

		next();
	});
}


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

	var cache = req.app.get('cache');
	if (cache && req.session_id)
	{
		var session_id = req.session_id;
		var cachename = [session_id, 'last_notification_check'].join('-');
		
		//console.log("CHECKING CACHE FOR " + cachename);
		req.app.get('cache').fetch(cachename, function(message) {
			if (typeof message.v == 'undefined' || !message.v)
			{
				//console.log("LAST VALUE SAVED WAS EMPTY");
				check_notifications(req, res, next);
			}
			else
			{
				var last_updated = parseInt(message.v);
				//console.log("LAST VALUE SAVED WAS " + last_updated);
				var now = parseInt((new Date()).getTime() / 1000);
				//console.log("DIFFERENCE: " + (now - last_updated));
				if ((now - last_updated) > 15) // TODO make configurable
				{
					//console.log("CHECKING NOTIFICATIONS...");
					check_notifications(req, res, next);
				}
				else
				{
					//console.log("SKIPPING...");
					next();
				}
			}
		});
	}
	else
	{
		check_notifications(req, res, next);
	}

};


