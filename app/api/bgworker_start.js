
const path = require('path');
const child_process = require('child_process');
const bgworker_lib = require(path.resolve(__dirname + '/../lib/ps_bgworker'));

module.exports = function() {

	return function(req, res) {
		var config = req.app.get('config');
		var ps_bgworker_path = config.ps_bgworker || 'ps_bgworker';
		var ps_bgworker_config = config.ps_bgworker_config || '';
		child_process.exec([ps_bgworker_path, ps_bgworker_config].join(' '),
			{
				timeout: 2000,
				encoding: 'utf8',
				cwd: config.base_directory
			},
			function(err, stdout, stderr) {
				if (err && !stdout)
				{
					res.status(200).json({'status': 'ERROR', 'error': err}).end();
					return;
				}

				var err = null;
				var lines = stdout.split("\n");
				lines.forEach(function(line) {
					if (line.startsWith('ERROR'))
					{
						err = line;
					}
				});

				if (err)
				{
					res.status(200).json({'status': 'ERROR', 'error': err, 'stdout': stdout}).end();
				}
				else
				{
					res.status(200).json({'status': 'OK', 'stdout': stdout}).end();
				}
			}
		);

	};
};

