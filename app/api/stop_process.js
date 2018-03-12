
const path = require('path');
const child_process = require('child_process');
const bgworker_lib = require(path.resolve(__dirname + '/../lib/ps_bgworker'));

module.exports = function() {

	return function(req, res) {
		res.locals.db.jsonb_call('grape.stop_running_schedule', {schedule_id: req.params.schedule_id}, function(err, result) {
			if (err)
			{
				var error_object = {
					'status': 'ERROR',
					'message': err.toString(),
					'code': -99,
					'error': err
				};

				res.jsonp(error_object);
				return;
			}

			var data = result.rows[0]['grapestop_running_schedule'];
			if (data.status == 'OK' && data.pid > 0)
				process.kill(data.pid, 'SIGTERM');
			
			res.jsonp(data);
			res.end();
		});

	};
};

