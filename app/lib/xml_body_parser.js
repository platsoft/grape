var libxmljs = require("libxmljs");

module.exports = function() {

	return function(req, res, next)  {
		var ar = [];
		var contenttype = '';
		var attributes = '';
		if (req.headers['content-type'])
		{
			ar = req.headers['content-type'].split(';');
			
			if (ar.length == 2)
			{
				var contenttype = ar[0];
				var attributes = ar[1];
			}
			else if (ar.length == 1)
			{
				var contenttype = ar[0];
				var attributes = '';
			}
			else
			{
				next();
				return;
			}
		}
		else
		{
			next();
			return;
		}

		if (contenttype == 'application/xml' || contenttype == 'text/xml')
		{
			var offset = 0;
			var buffer = Buffer.alloc(parseInt(req.headers['content-length']));
			req.on('data', function(d) {
				offset += d.copy(buffer, offset);
			});
			req.on('end', function(d) {
				// TODO  check if valid encoding
				var xmlString = buffer.toString('utf8');
				req.body = libxmljs.parseXmlString(xmlString, { noblanks: true });
				// TODO check errors in XML req.body.errors.length should be 0
				next();
			});
			req.on('error', function(d) {
				res.end(); //TODO
			});
		}
		else
		{
			next();
			return;
		}
	};
}

