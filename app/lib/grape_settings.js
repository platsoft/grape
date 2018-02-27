


var GrapeSettings = function(grape_app) {
	this.app = grape_app;
	var self = this;
	this.self = self;

	this.settings = {};

	this.reload = function() {
		self.app.logger.log('app', 'info', 'Loading settings');
		var new_settings = {};
		var qry = self.app.db.query('SELECT * FROM grape.setting');
		qry.on('row', function(row) {
			self.app.logger.debug('app', 'Loaded setting', row.name);
			new_settings[row.name] = row;
		});
	};

	this.setup = function() {
		if (self.app.db)
		{
			self.app.db.new_notify_handler('reload_settings', self.reload);
			self.reload();
		}
		else
		{
			self.app.logger.error('app', 'No DB found to load settings from');
		}
	};

	this.get_value = function(name, default_value) {
		if (!self.settings[name])
			return default_value;

		return self.settings[name].value || default_value;
	};
};

module.exports = GrapeSettings;


