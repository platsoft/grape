
const assert = require('assert');
const cluster = require('cluster');
const path = require('path');
const grapelib = require('../../app/index.js');

var grape = new grapelib.grape(path.join(__dirname, '..', 'project', 'test_config.json'), {
		base_directory: __dirname + '/../'
	});

grape.start();

