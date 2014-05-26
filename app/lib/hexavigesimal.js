
exports.bijb262decimal = function (inp) {
	var ret = 0;
	for (var i = 0; i < inp.length; i++)
		ret += (inp.charCodeAt(i) - 64) * (Math.pow(26, inp.length - i - 1));
	return ret;
};

exports.decimal2bijb26 = function (inp) {
	var ret = '';
	var n = inp;
	while (n > 0)
	{
		n--;
		ret = String.fromCharCode(65 + (n%26)) + ret;
		n = parseInt(n / 26);
	}

	return ret;
};

