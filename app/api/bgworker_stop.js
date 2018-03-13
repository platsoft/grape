
const path = require('path');
var bgworker_lib = require(path.resolve(__dirname + '/../lib/ps_bgworker'));

module.exports = function() {

	return function(req, res) {

		var config = req.app.get('config');
		var ps_bgworker_path = config.ps_bgworker || 'ps_bgworker';
		var ps_bgworker_config = config.ps_bgworker_config || '';

		bgworker_lib.get_bgworker_status(ps_bgworker_path, ps_bgworker_config, function(err, obj) {
			if (err)
			{
				res.status(200).json({'status': 'ERROR', 'error': err}).end();
				return;
			}
			process.kill(obj.pid);
			res.status(200).json({'status': 'OK', 'pid': obj.pid}).end();
		});
	};
};

