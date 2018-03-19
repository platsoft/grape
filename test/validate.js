
var assert = require('assert');
var auto_validate = require('../app/lib/auto_validate.js');



describe('Testing auto validate', function() {
	it('Testing valid integers', function(done) {

		var ret = auto_validate.validate(
			{product_id: 10109},
			'(product_id:i)');

		if (ret.errors.length > 0)
			assert.fail(ret.errors.length, 0, 'Integer was valid');
		
		done();
	});

	it('Testing invalid integers', function(done) {

		var ret = auto_validate.validate(
			{product_id: 1010.39},
			'(product_id:i)');

		if (ret.errors.length != 1)
			assert.fail(ret.errors.length, 1, 'Integer was invalid');
		
		done();
	});
	it('Testing invalid integers', function(done) {

		var ret = auto_validate.validate(
			{product_id: 'ssss'},
			'(product_id:i)');

		assert.equal(ret.errors.length, 1, 'Integer was invalid');
		
		done();
	});
	it('Testing nullable', function(done) {
		var ret = auto_validate.validate({product_id: null}, "(product_id: s)");
		assert.equal(ret.errors.length, 1);
		done();

	});

	it('Testing failed decoding of validation string', function(done) {
		var ret = auto_validate.validate({product_id: 1}, "product_id: s)");
		assert.notEqual(ret.errors.length, 0);
		done();

	});

	it('Testing arrays', function(done) {
		var ret = auto_validate.validate({product_id: 1}, "(product_id: [i])");
		assert.equal(ret.errors.length, 1);
		done();

	});

	it('Testing arrays of simple values', function(done) {
		var ret = auto_validate.validate({product_id: [1,2,3]}, "(product_id: [i])");
		assert.equal(ret.errors.length, 0);
		done();

	});

	it('Testing error in arrays of simple values', function(done) {
		var ret = auto_validate.validate({product_id: [1,'s',3]}, "(product_id: [i])");
		assert.equal(ret.errors.length, 1);
		done();

	});
	it('Testing error in arrays of objects', function(done) {
		var ret = auto_validate.validate({product: [2]}, "(product: [(name:i)])");
		assert.equal(ret.errors.length, 1);
		done();

	});
	it('Testing error in arrays of objects', function(done) {
		var ret = auto_validate.validate({product: [{name:'s'}]}, "(product: [(name:i)])");
		assert.equal(ret.errors.length, 1);
		done();

	});
	it('Testing valid arrays of objects', function(done) {
		var ret = auto_validate.validate({product: [{name:3}]}, "(product: [(name:i)])");
		assert.equal(ret.errors.length, 0);
		done();

	});
	it('Testing valid object in object', function(done) {
		var ret = auto_validate.validate({product: {name:3}}, "(product: (name:i))");
		assert.equal(ret.errors.length, 0);
		done();

	});
	it('Testing invalid object in object', function(done) {
		var ret = auto_validate.validate({product: 'a'}, "(product: (name:i))");
		assert.equal(ret.errors.length, 2);
		done();

	});
	it('Testing valid optional', function(done) {
		var ret = auto_validate.validate({}, "(product:s*)");
		assert.equal(ret.errors.length, 0);
		done();

	});
	it('Testing valid empty becomes null', function(done) {
		var ret = auto_validate.validate({}, "(product:s*E)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing empty becomes null on null', function(done) {
		var ret = auto_validate.validate({product:null}, "(product:E0)");
		assert.equal(ret.errors.length, 0);
		done();
	});

	it('Testing validation string without valid data type', function(done) {
		var ret = auto_validate.validate({product:'s'}, "(product:x)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing valid datatype object', function(done) {
		var ret = auto_validate.validate({product:{p:3}}, "(product:a)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing invalid datatype object', function(done) {
		var ret = auto_validate.validate({product:'s'}, "(product:a)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing invalid datetime', function(done) {
		var ret = auto_validate.validate({product:'dsds'}, "(product:d)");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing valid datetime', function(done) {
		var ret = auto_validate.validate({product:'2019-01-01'}, "(product:d)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing valid datetime', function(done) {
		var ret = auto_validate.validate({product:'01-01-2019'}, "(product:d)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing valid float', function(done) {
		var ret = auto_validate.validate({product:23.45}, "(product:f)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing invalid float', function(done) {
		var ret = auto_validate.validate({product:'dsds'}, "(product:f)");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing valid boolean false', function(done) {
		var ret = auto_validate.validate({product:'false'}, "(product:b)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing valid boolean true', function(done) {
		var ret = auto_validate.validate({product:'true'}, "(product:b)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing invalid boolean', function(done) {
		var ret = auto_validate.validate({product:'flse'}, "(product:b)");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing valid string', function(done) {
		var ret = auto_validate.validate({product:'true'}, "(product:s)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing invalid json', function(done) {
		var ret = auto_validate.validate({product:'{"a":ss}'}, "(product:j)");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing valid json', function(done) {
		var ret = auto_validate.validate({product:'{"a":"ss"}'}, "(product:j)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing missing closing bracket', function(done) {
		var ret = auto_validate.validate({product:'{"a":"ss"}'}, "(product:j");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing type set twice', function(done) {
		var ret = auto_validate.validate({product:'ss'}, "(product:is)");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing whitespace in varname', function(done) {
		var ret = auto_validate.validate({product:'{"a":"ss"}'}, "(product :s)");
		assert.equal(ret.errors.length, 0);
		done();
	});
	it('Testing missing datatype indicator in array def', function(done) {
		var ret = auto_validate.validate({product:'{"a":"ss"}'}, "(product :[l])");
		assert.equal(ret.errors.length, 1);
		done();
	});
	it('Testing two different variables', function(done) {
		var ret = auto_validate.validate({product:'aa',product2:2}, "(product :s,product2:i)");
		assert.equal(ret.errors.length, 0);
		done();
	});

	it('Testing array with objects', function(done) {
		var ret = auto_validate.validate({products:[{product:'aa'}]}, "(products:[(product:s)])");
		assert.equal(ret.errors.length, 0);
		done();
	});










	it('Testing null permissible for empty string with E0', function(done) {
		var ret = auto_validate.validate({product: ''}, "(product: sE0)");
		assert.equal(ret.errors.length, 0);
		done();

	});

	it('Testing missing item in array of objects inside nested objects', function(done) {
		var ret = auto_validate.validate({
			product: {
				def: {
					products: [
						{product_id: 1},
						{product_isd: 2},
						{product_id: 3}
					]
				}
			}
		},
		"(product: (def: (products:[(product_id:i)]])))");

		assert.equal(ret.errors.length, 1);
		done();
	});

});

/*
}, "(product_id:i)", check_errors_1);
test('Testing invalid integers', {
	product_id: 'sdsds'
}, "(product_id:i)", check_errors_1);




var colors = require('colors');

var level = 0;

function print_info (str) { console.error("  ".repeat(level) + colors.blue(str)); }
function print_ok (str) { console.error("  ".repeat(level) + colors.green(str)); }
function print_warn (str) { console.error("  ".repeat(level) + colors.yellow(str)); }
function print_err (str) { console.error("  ".repeat(level) + colors.red(str)); }



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
		{
			print_err('FAILED');
			print_warn('	object: ' + JSON.stringify(obj));
			print_warn('	string: ' + string);
			print_warn('	result: ' + JSON.stringify(ret));
		}
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
test('Testing empty becomes NULL modifier', o, "(product_id:i,optional_id:iE*)", function(ret) {
	console.log('Checking that optional_id was added as null');
	if (ret.errors.length > 0 || o.optional_id !== null)
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







test('Testing not-null enforcement of empty string', {
	product: ''
}, "(product: sE)", check_errors_1);

test('Testing optional enforcement of empty string', {
	product: ''
}, "(product: s)", check_errors_0);

test('Testing null permissible for empty string with E0', {
	product: ''
}, "(product: sE0)", check_errors_0);

test('Testing nullable not triggered by name', {
        product0: null
}, "(product0: s)", check_errors_1);

test('Testing optional not triggered by name', {
	other_product: 'alpha'
}, "(product*: s)", check_errors_1);

test('Testing optional not triggered by name when empty', {
	other_product: 'alpha'
}, "(product*: sE)", check_errors_1);
*/
