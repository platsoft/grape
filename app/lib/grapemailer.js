
var fs = require('fs');
var path = require('path');
var nodemailer = require('nodemailer');
var _ = require('underscore');

function GrapeMailer(_o) 
{
	var self = this;
	self.app_config = _o;
	self.error = null;
	self.transporter = null;

	/* 
	 * 0 = success
	 * -1 = no smtp settings found
	 */
	this.create_transporter = function() {
		if (!self.transporter)
		{
			if (!self.app_config.smtp)
			{
				self.error = 'Error: no smtp settings found in app config';
				return -1;
			}

			// TODO set this in config
			process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

			self.transporter = nodemailer.createTransport(
					['smtps://', self.app_config.smtp.auth.user, ':', self.app_config.smtp.auth.pass, '@', self.app_config.smtp.host].join('')
					); 


		}
		return self.transporter;
	};

	this.assemble_mail_options = function(_email) {
		var defaults = {
			
			from: '',
			to: '',
			subject: '',
			text: '',
			html: '',
			template: '',
			template_data: {},
			attachments: []
		};

		var mailOptions = _.extend(defaults, _email);

		if (mailOptions.template != '')
		{
			if (!self.app_config.email_template_directory)
			{
				self.error = 'Error: no email template directory found in config (email_template_directory)';
				return -1;
			}

			var email_template_directory = self.app_config.email_template_directory;

			// TODO cache templates
			function proc_template(template_name, type, d)
			{
				//console.log("Processing template ", template_name, type, d);

				var template_file = [email_template_directory, '/', template_name, '.', type].join('');
				var tmpl_data = null;

				try {
					tmpl_data = fs.readFileSync(template_file, 'utf8');
				} catch (e) { tmpl_data = null; }

				if (tmpl_data)
				{
					var tmpl = _.template(tmpl_data);
					
					//console.log("Found template data");

					try {
						var ret = tmpl(d);
					} catch (e) { 
						self.error = 'Error when processing template file ' + template_file + ' (' + e + ')';
						return -1;
					}

					return ret;
				}
				return null;
			}

			mailOptions.text = proc_template(mailOptions.template, 'text', mailOptions.template_data) || mailOptions.text;
			mailOptions.html = proc_template(mailOptions.template, 'html', mailOptions.template_data) || mailOptions.html;
			mailOptions.subject = proc_template(mailOptions.template, 'subject', mailOptions.template_data) || mailOptions.subject;

			if (mailOptions.text == -1)
				return null;
			if (mailOptions.html == -1)
				return null;
			if (mailOptions.subject == -1)
				return null;

			var attachments_file = [email_template_directory, '/', mailOptions.template, '.attachments'].join('');
			var tmpl_attachments_data = null;

			try {
				tmpl_attachments_data = fs.readFileSync(attachments_file, 'utf8');

				var rows = tmpl_attachments_data.split("\n");
				rows.forEach(function(row) {
					if (row == '')
						return;
					var filename = path.basename(row);
					var filepath = path.normalize(email_template_directory + '/' + row);
					mailOptions.attachments.push({filename: filename, path: filepath, cid: filename});
				});
			} catch (e) { console.log("Exception ", e); }
		}

		return mailOptions;
	};

	//callback with 2 params, err and info
	this.send = function(email, cb) {
		self.create_transporter();
		var mailOptions = self.assemble_mail_options(email);
		if (mailOptions == null)
		{
			cb(self.error, null);
			return;
		}
		self.transporter.sendMail(mailOptions, cb); 
	};
}



module.exports.send_email = function(_config, _email, cb) {
	var emailer = new GrapeMailer(_config);
	if (emailer.create_transporter() == -1)
	{
		console.log("ERR", self.error);
		cb(self.error, null);
		return;
	}

	emailer.send(_email, cb);
};


module.exports.GrapeMailer = GrapeMailer;

