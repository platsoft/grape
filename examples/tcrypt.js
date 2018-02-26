
var fs = require('fs');
var crypto = require('crypto');

var hashes = crypto.getHashes();
	
var privateKey = fs.readFileSync('/home/hans/.platsoft/private/hans.key', 'utf8');

hashes.forEach(function(hash) {
	console.log(hash);
	try {
		var sign = crypto.createSign(hash);
		sign.write('1234');
		sign.end();

		var signature = sign.sign(privateKey, 'base64');
		console.log(signature);
		console.log(signature.length + ' bytes');
	} catch (e) {
		console.log("Fail");
	}
});


