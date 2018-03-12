const path = require('path');

module.exports = function() {
	return function(req, res) {
		var schedule_id = req.params.schedule_id;
		var offset = 0;

		res.locals.db.json_call('grape.schedule_info', {schedule_id: req.params.schedule_id}, function(err, result) {
			if (err)
			{
				res.json('{}').end(); //ERROR
				return;
			}

			var obj = result.rows[0]['grapeschedule_info'];
			var schedule = obj.schedule;

			if (schedule.logfile[0] === '~') {
				schedule.logfile = path.join(process.env.HOME, schedule.logfile.slice(1));
			}
			var logfilename = path.resolve(schedule.logfile);

			try {
				res.sendFile(logfilename); 
			}
			catch (e) {
				console.log(e);
				res.send(e).end(); //ERROR
				return;
			}
		});
	};
}

