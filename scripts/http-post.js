/**
 * http-post
 *
 * (c) copyright 2012 Sam Thompson <sam@emberlabs.org>
 * License: The MIT License - http://opensource.org/licenses/mit-license.php
 */

module.exports = function(options, data, files, fn) {
	if (typeof(files) == 'function' || typeof(files) == 'undefined') {
		fn = files;
		files = [];
	}

	if (typeof(fn) != 'function') {
		fn = function() {};
	}

	if (typeof(options) == 'string') {
		var options = require('url').parse(options);
	}

	var fs = require('fs');
	var endl = "\r\n";
	var length = 0;
	var contentType = '';

	// If we have files, we have to chose multipart, otherweise we just stringify the query 
	if (files.length) {
		var boundary = '-----np' + Math.random();
		var toWrite = [];

		for(var k in data) {
			toWrite.push('--' + boundary + endl);
			toWrite.push('Content-Disposition: form-data; name="' + k + '"' + endl);
			toWrite.push(endl);
			toWrite.push(data[k] + endl);
		}

		var name = '', stats;
		for (var k in files) {
			// Determine the name
			name = (typeof(files[k].name) == 'string') ? files[k].name : files[k].path.replace(/\\/g,'/').replace( /.*\//, '' );

			if (files[k].data)
			{
				files[k].length = files[k].data.length;
				
			}
			else if (fs.existsSync(files[k].path)) {

				// Determine the size and store it in our files area
				stats = fs.statSync(files[k].path);
				files[k].length = stats.size;

			}

			toWrite.push('--' + boundary + endl);
			toWrite.push('Content-Disposition: form-data; name="' + files[k].param + '"; filename="' + name + '"' + endl);
			toWrite.push(endl);
			toWrite.push(files[k]);
			toWrite.push(endl);

		}

		// The final multipart terminator
		toWrite.push('--' + boundary + '--' + endl);

		// Now that toWrite is filled... we need to determine the size
		for(var k in toWrite) {
			length += toWrite[k].length;
		}

		contentType = 'multipart/form-data; boundary=' + boundary;
	}
	else {
		data = require('querystring').stringify(data);

		length = data.length;
		contentType = 'application/x-www-form-urlencoded';
	}

	options.method = 'POST';
	if (!options.headers)
		options.headers = {};
	options.headers['Content-Type'] = contentType;
	options.headers['Content-Length'] = length;

	var req = require('http').request(options, function(responce) {
		fn(responce);
	});

	var total = 0;

	// Multipart and form-urlencded work slightly differnetly for sending
	if (files.length) {
		for(var k in toWrite) {
			console.log("Writing " + toWrite[k].length + " bytes");
			total += toWrite[k].length;
			if (typeof(toWrite[k]) == 'string') {
				req.write(toWrite[k]);
			}
			else if (toWrite[k].data)
			{
				req.write(toWrite[k].data);
			}
			else {
				// @todo make it work better for larger files
				var data = fs.readFileSync(toWrite[k].path);
				req.write(data);
			}
		}
	}
	else {
		req.write(data);
	}
	console.log("TOTAL : " + total);
	req.end();

	return req;
}

