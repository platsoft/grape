
const assert = require('assert');
const cluster = require('cluster');
const path = require('path');
const grapelib = require('../app/index.js');

var grape = null;

describe('Testing Grape App', function() {
	it('Creating grape app', function(done) {

		grape = new grapelib.grape(__dirname + '/test_config.json', {
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
		var gc = new grapelib.grapeclient({url: 'http://admins:admin123@localhost:60890/'});
		gc.postJSON('/grape/list', {}, function(ret) {
			assert.equal(ret.status, 'ERROR');
			done();
		});
	})

	it ('Performing valid login request', function(done) {
		var gc = new grapelib.grapeclient({url: 'http://admin:admin123@localhost:60890/'});
		gc.postJSON('/grape/list', {}, function(ret) {
			assert.equal(ret.status, 'ERROR');
			done();
		});
	})

});




