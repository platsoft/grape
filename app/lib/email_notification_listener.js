var gutil;
var send_email = require(__dirname + '/../lib/grapemailer.js').send_email;


function EmailNotificationListener(_o)
{
	var self = this;
	this.self = self;
	
	var grapelib = require(__dirname + '/../index.js');
	this.options = grapelib.options(_o);
	this.logger = new grapelib.logger(this.options);

	this.setup_db = function() {
		var _db = require(__dirname + '/db.js');
		var db = new _db({
			dburi: self.options.dburi,
			debug: self.options.debug,
			session_id: 'email_notification_listener'
		});

		db.on('error', function(err) {
			self.logger.log('db', 'error', err);
		});

		db.on('debug', function(msg) {
			self.logger.log('db', 'debug', msg);
		});

		db.on('end', function() {
			self.logger.log('db', 'info', 'Database disconnected. Restarting');
			db.connect();
		});


		db.new_notify_handler('grape_send_email', self.notification_email);

		self.db = db;
	};

	this.notification_email = function(d)
	{
		var data = JSON.parse(d);

		var config = self.options;

		var headers = data.headers || {};

		if (data.email && data.email_template && data.template_data)
		{
			headers.from = config.smtp.from;
			if (headers['From'])
			{
				headers.from = headers['From'];
			}

			// Send email
			var mail = {
				from: headers.from,
				to: data.email,
				template: data.email_template,
				template_data: data.template_data,
				headers: headers
			};

			self.logger.debug('Sending ' + data.email_template + ' email to ' + data.email + ' with template data ' + JSON.stringify(data.template_data));

			send_email(config, mail, function(err, data)
			{
				if (err)
				{
					self.logger.error('Error sending email - ' + JSON.stringify(err)); 
					return;
				}
				
				self.logger.debug('Email sent - ' + JSON.stringify(data));
			});
		}
		else
		{
			self.logger.debug('Not sending email - missing fields (I need email, email_template and template_data)');
		}
	};


	this.start = function() {
		if (self.options.email_template_directory && self.options.smtp)
		{
			this.setup_db();
		}
		else
		{
			self.logger.log('error', 'missing config email_template_directory and smtp, you will not be able to send emails');
		}
	};

}

module.exports.EmailNotificationListener = EmailNotificationListener;


