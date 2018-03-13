"use strict";
var qrcode =  require('qrcode-npm');
var base32 = require('thirty-two');

module.exports = function() {

	return function (req, res)
	{
		res.locals.db.jsonb_call('grape.enable_totp', {}, function(err, result) {
			if (err || !result.rows) 
			{
				res.jsonp({
					'status': 'ERROR',
					'message': err.toString(),
					'code': -99,
					'error': err
				}).end();
				return;
			};
			var obj = result.rows[0]['grapeenable_totp'];
				
			console.log(obj);

			if (obj.status == 'ERROR')
			{
				res.jsonp(obj);
			}
			else
			{
				var secret = obj.key;
				var secret_b32 = base32.encode(secret);
				var qr = qrcode.qrcode(10, 'M');

				var data = obj.provisioning_url.replace('INSERT_SECRET_HERE', secret_b32);

				qr.addData(data);

				qr.make();
				var img_tag = qr.createImgTag(4);
				res.jsonp({
					'qrcode': img_tag
				});
			}
		});
	}
};

