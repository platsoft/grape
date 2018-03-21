
const assert = require('assert');
const cluster = require('cluster');
const path = require('path');
const http = require('http');
const grapelib = require('../app/index.js');

var grape = null;
var gc = null;

function http_request(options, cb) {
	console.log(options);

	var req = http.request(options, function(res) {
		res.setEncoding('utf8');
		var chunks = [];
		console.log('aaa');
		res.on('data', function(chunk) {
			chunks.push(chunk);
		});
		res.on('end', function() {
			var obj = chunks.join('');
			cb(null, data, res);
		});
		res.on('error', function(err) {
			cb(err, null, res);
		});
	});
	req.end();
	return req;
};

describe('Testing Grape App', function() {
	it('Creating grape app', function(done) {

		grape = new grapelib.grape(path.join(__dirname, 'project', 'test_config.json'), {
			base_directory: __dirname
		});

		if (cluster.isMaster)
		{
			cluster.setupMaster({exec: path.join(__dirname, '/helpers/start_worker_app.js')});
			grape.on('master-after-start', function(e) {
				setTimeout(done, 1000);
			});
		}
		
		grape.start();
	})

	it ('Performing invalid login request', function(done) {
		gc = new grapelib.grapeclient({url: 'http://localhost:60890/'});
		gc.login('piet', 'pompies', function(err, ret) {
			assert.equal(err, null);
			assert.equal(ret.status, 'ERROR');
			done();
		});
	})

	it ('Performing valid login request', function(done) {
		gc.login('admin', 'admin123', function(err, ret) {
			assert.equal(err, null);
			assert.equal(ret.status, 'OK');
			done();
		});
	})

	it ('Testing download_public_js_files', function(done) {
		http_request({
			hostname: 'localhost',
			path: '/download_public_js_files',
			method: 'GET',
			port: grape.options.port
		}, function(err, data, res) {
			assert.equal(err, null);
			console.log(data);
			done();
		});

		//gc.login('admin', 'admin123', function(err, ret) {
		//	assert.equal(err, null);
		//	assert.equal(ret.status, 'OK');
		//	done();
		//});
	})

	it ('Shutting down', function(done) {
		process.kill(process.pid, 'SIGINT');
		grape.shutdown();
		done();
		process.exit(1);
	});


	/*
	it ('Performing valid login request', function(done) {
		var gc = new grapelib.grapeclient({url: 'http://admin:admin123@localhost:60890/'});
		gc.postJSON('/grape/list', {}, function(ret) {
			assert.equal(ret.status, 'ERROR');
			done();
		});
	})
	*/

});




