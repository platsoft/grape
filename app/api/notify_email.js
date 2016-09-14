var gutil;
var send_email = require(__dirname + '/../lib/grapemailer.js').send_email;
var app;

exports = module.exports = function(_app) {
	app = _app;
	gutil = app.get('gutil');

	if (app.get('config').email_template_directory && app.get('config').smtp)
	{
		app.get('db').new_notify_handler('grape_send_email', notification_email);
	}
}

function notification_email(d)
{
	var data = JSON.parse(d);

	var config = app.get('config');

	if (data.email && data.email_template && data.template_data)
	{
		// Send email
		var mail = {
			from: config.smtp.from,
			to: data.email,
			template: data.email_template,
			template_data: data.template_data
		};

		app.get('logger').debug('Sending ' + data.email_template + ' email to ' + data.email + ' with template data ' + JSON.stringify(data.template_data));

		send_email(config, mail, function(err, data)
		{
			if (err)
			{
				app.get('logger').error(err);
				return;
			}
			
			app.get('logger').debug('Email sent - ' + JSON.stringify(data));
		});
	}
	else
	{
		app.get('logger').debug('Not sending email - missing fields (I need email, email_template and template_data)');
	}
}

