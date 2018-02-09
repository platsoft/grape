

var colors = require('colors');

var level = 0;

function print_info (str) { console.error("  ".repeat(level) + colors.blue(str)); }
function print_ok (str) { console.error("  ".repeat(level) + colors.green(str)); }
function print_warn (str) { console.error("  ".repeat(level) + colors.yellow(str)); }
function print_err (str) { console.error("  ".repeat(level) + colors.red(str)); }


var auto_validate = require('../app/lib/auto_validate.js');

function test(descr, obj, string, check_func)
{
	console.log(descr);

	var ret = auto_validate.validate(obj, string);

	//console.log(JSON.stringify(ret, null, '    '));
	
	if (check_func)
	{
		var result = check_func(ret, obj);
		if (ret.errors.length > 0)
			print_warn(ret.errors.join("\n"));
		if (result)
			print_ok('OK');
		else
			print_err('FAILED');
	}

	console.log();
}


function check_errors_0(obj)
{
	if (obj.errors.length)
		return false;
	else
		return true;
}
function check_errors_1(obj)
{
	if (obj.errors.length == 1)
		return true;
	else
		return false;
}
function check_errors_2(obj)
{
	if (obj.errors.length == 2)
		return true;
	else
		return false;
}



test('Testing valid integers', {
	product_id: 10109
}, "(product_id:i)", check_errors_0);
test('Testing invalid integers', {
	product_id: 10109.23
}, "(product_id:i)", check_errors_1);
test('Testing invalid integers', {
	product_id: 'sdsds'
}, "(product_id:i)", check_errors_1);




test('Testing valid boolean', {
	stuff: true
}, "(stuff:b)", check_errors_0);

test('Testing invalid boolean', {
	stuff: 3
}, "(stuff:b)", check_errors_1);




test('Testing optional modifier', {
	product_id: 1
}, "(product_id:i,optional_id:i*)", check_errors_0);


test('Testing nullable modifier', {
	product_id: 1,
	optional_id: null
}, "(product_id:i,optional_id:i0)", check_errors_0);
test('Testing without modifier', {
	product_id: 1,
	optional_id: null
}, "(product_id:i,optional_id:i)", check_errors_1);

var o = {product_id: 1};
test('Testing empty becomes NULL modifier', o, "(product_id:i,optional_id:iE)", function(ret) {
	console.log('Checking that errors.length is 0');
	if (ret.errors.length > 0)
		return false;

	console.log('Checking that field was set');
	if (o.optional_id === null)
		return true;
	else
		return false;
});




test('Testing nested objects', {
	product: {
		def: {
			product_id: 1
		},
		message: 'abc',
		def2: {
			p1: 9,
			p2: 'abc',
			def3: {
				abc: 'abc'
			}
			
		}
	}
}, "(product: (def: (product_id:i), def2: (p1:i,p2:s,def3:(abc:s)), message:s))", check_errors_0);


test('Testing arrays', {
	product_ids: [1,3,4,5]
}, "(product_ids:[i])", check_errors_0);


test('Testing arrays inside object', {
	stuff: {product_ids: [1,3,4,5]}
}, "(stuff:(product_ids:[i]))", check_errors_0);


test('Testing objects inside array', {
	stuff: [{product_id: 1, name: 'abc'}]
}, "(stuff:[(product_id:i,name:s)])", check_errors_0);

test('Testing nested objects inside array', {
	products: [{
		def: {
			product_id: 1
		},
		message: 'abc',
		def2: {
			p1: 1,
			p2: 'abc',
			def3: {
				abc: 'abc'
			}
		}
	}]
}, "(products: [(def: (product_id:i), def2: (p1:i,p2:s,def3:(abc:s)), message:s)])", check_errors_0);

test('Testing nested objects with missing fields inside array', {
	products: [{
		def: {
			product_id: 1
		},
		message: 'abc',
		def2: {
			p1: 1,
			p2: 'abc',
			def3: {
				abc: 'abc'
			}
		}
	}, {def: {product_id: 2}}]
}, "(products: [(def: (product_id:i), def2: (p1:i,p2:s,def3:(abc:s)), message:s)])", check_errors_2);

test('Testing array inside nested objects', {
	product: {
		def: {
			product_ids: [1,2,3]
		}
	}
}, "(product: (def: (product_ids:[i])))", check_errors_0);

test('Testing invalid array inside nested objects', {
	product: {
		def: {
			product_ids: [1,'s',3]
		}
	}
}, "(product: (def: (product_ids:[i])))", check_errors_1);

test('Testing array of objects inside nested objects', {
	product: {
		def: {
			products: [
				{product_id: 1},
				{product_id: 2},
				{product_id: 3}
			]
		}
	}
}, "(product: (def: (products:[(product_id:i)]])))", check_errors_0);

test('Testing missing item in array of objects inside nested objects', {
	product: {
		def: {
			products: [
				{product_id: 1},
				{product_isd: 2},
				{product_id: 3}
			]
		}
	}
}, "(product: (def: (products:[(product_id:i)]])))", check_errors_1);




