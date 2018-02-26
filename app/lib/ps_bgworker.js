
var child_process = require('child_process');


module.exports.get_bgworker_status = function(ps_bgworker_path, config_file, cb) {

	child_process.exec([ps_bgworker_path, '--status'].join(' '),
		{
			timeout: 2000,
			encoding: 'utf8'
		},
		function(err, stdout, stderr) {
			if (err && !stdout)
			{
				cb(err, {stdout: stdout, stderr: stderr});
				return;
			}

			var obj = {pid: 0, cmdline: ''};

			var lines = stdout.split("\n");
			if (lines[0] == "Not running")
			{
				cb(null, obj);
			}
			else
			{
				lines.forEach(function(line) {
					if (line.trim() != '')
					{
						var ar = line.split(':');
						if (ar.length == 2)
						{
							var k = ar[0];
							if (k == 'PID')
							{
								obj.pid = parseInt(ar[1]);
							}
							else if (k == 'CMDLINE')
							{
								obj.cmdline = ar[1];
							}
						}
					}
				});

				cb(null, obj);
			}
		}
	);
}


