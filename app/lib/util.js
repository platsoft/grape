
var gutil = function(){ };

gutil.prototype.trim = function(str) { 
	return str.replace(/^[\s]+/, '').replace(/[\s]+$/, '');
};
gutil.prototype.formatDate = function(dte) { 
	if (!dte)
		return '';
	if (typeof dte == 'string')
		var dte = new Date(dte);
	var y = dte.getFullYear();
	var m = dte.getMonth() + 1;
	var d = dte.getDate();
	return y + '/' + (m < 10 ? '0' : '') + m + '/' + (d < 10 ? '0' : '') + d;
};
gutil.prototype.formatDateTime = function(dte) {
	if (!dte)
		return '';
	if (typeof dte == 'string')
		var dte = new Date(dte);
	var y = dte.getFullYear();
	var m = dte.getMonth() + 1;
	var d = dte.getDate();
	var mm = dte.getMinutes();
	var hh = dte.getHours();

	return y + '/' + (m < 10 ? '0' : '') + m + '/' + (d < 10 ? '0' : '') + d + ' ' + (hh < 10 ? '0' : '') + hh + ':' + (mm < 10 ? '0' : '') + mm;
};


/*
 * muid = unique message id, 32 bit integer
 * command = command, 32 bit integer
 * obj = message data
 * 
 * message structure:
 * <0x01               0x00 0x00 0x00 0x00    0x00 0x00 0x00 0x01  0x00 0x00 0x00 0x00     .. .. .. .. ..  
 *  START OF HEADER    UNIQUE MESSAGE ID      COMMAND INTEGER      PAYLOAD LENGTH          UTF8 encoded payload
 *  
 *  Fields explained:
 *  
 *  START OF HEADER   (ASCII control ^A) 1 byte
 *  UNIQUE MESSAGE ID A unique ID to identify this request 32-bit unsigned integer
 *  COMMAND INTEGER  32 bit unsigned integer identifiying the command
 *  PAYLOAD LENGTH  32 bit unsigned integer speciifcying the payload size
 *  PAYLOAD	    UTF-8 encoded message data
 *
 *  Note: All integers are unsigned big endian
 */
gutil.encodeMessage = function (muid, command, obj) {
	var str_data = JSON.stringify(obj);
	var length = Buffer.byteLength(str_data, 'utf8');
	
	var buff = new Buffer(length + 1 + 4 + 4 + 4);
	buff.fill(0);
	// offset 0 - 0x1 start message
	buff.writeUInt8(0x1, 0);

	// offset 1 - muid
	buff.writeUInt32BE(muid, 1);
	
	// offset 5 - command integer
	buff.writeUInt32BE(command, 5);
	
	// offset 9 - payload length
	buff.writeUInt32BE(length, 9);
	
	// offset 13 - payload
	buff.write(str_data, 13, length, 'utf8');

	return buff;
};

/**
 * Returns muid, cmmand and data
 *
 */
gutil.decodeMessage = function (buff)
{
	var head = buff.readUInt8(0);
	var muid = buff.readUInt32BE(1);
	var command = buff.readUInt32BE(5);
	var length = buff.readUInt32BE(9);

	var str_data = buff.toString('utf8', 13, length+13);
	var obj = JSON.parse(str_data);

	var ret = { 
		muid: muid,
		command: command,
		data: obj
	};

	return ret;
};

// Check for the existence of all fields in the array fields, in object obj
// returns array of missing fields, or null if all fields are present 
gutil.all_fields_exists = function (fields, obj) {
	var ret = null;
	
	for (var i = 0; i < fields.length; i++)
	{
		var f = fields[i];
		if (typeof obj[f] == 'undefined')
		{
			if (!ret)
				ret = [];
			ret.push(f);
		}
	}
	
	return ret;
};

gutil.generate_api_error = function (message, code, err_info) {
	if (!err_info)
		var err_info = {};
	
	return {
		'status': 'ERROR',
		'code': code,
		'message': message,
		'error': err_info
	};
};

module.exports = gutil;


