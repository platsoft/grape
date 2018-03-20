// perform some common checks on a grape app object
//

const async = require('async');
const fs = require('fs');

module.exports = function(grape_app) {

	function check_grape_version(done)
	{
		try {
			var pkg = JSON.parse(fs.readFileSync(__dirname + '/../../package.json', 'utf8'));
		} catch (e) {
			grape_app.logger.error('app', 'Error when loading package.json');
			done(null);
			return;
		}

		var db_grape_version = grape_app.grape_settings.get_value('grape_version', '0');
		if (db_grape_version != pkg.version)
		{
			grape_app.logger.crit('app', 'The grape version in your database (', db_grape_version, ') does not match the one that is currently running (', pkg.version, '). Please apply the necessary patches to get your database up too date');
			grape_app.db.disconnect(true); // going to quit
		}
		else
		{
			done(null);
		}
	}

	function check_directories(done)
	{
		grape_app.options.public_directories.forEach(function(dir) {
			try {
				var stat = fs.statSync(dir);
			} catch (e) { 
				grape_app.logger.warn('app', 'Configuration error: public directory', dir, 'could not be read');
			}
		});

		grape_app.options.api_directories.forEach(function(dir) {
			try {
				var stat = fs.statSync(dir);
			} catch (e) { 
				grape_app.logger.warn('app', 'Configuration error: public directory', dir, 'could not be read');
			}
		});


		done(null);
	}

	function check_settings(done)
	{
		if (grape_app.grape_settings.get_value('service_name', '') == '')
		{
			grape_app.logger.crit('app', 'Your system is missing the "service_name" setting. Please set it up before starting grape. If you have grape-shell installed, you can do this by using grape-shell -r "setting set service_name myservicename.local"');
			grape_app.db.disconnect(true); // going to quit
		}
		else
		{
			done(null);
		}
	}

	return function(done) {
		async.series([check_grape_version, check_directories, check_settings], function(err, results) {
			if (done)
				done();
		});
	};
};
