
const assert = require('assert');
const cluster = require('cluster');
const path = require('path');
const grapelib = require('../../app/index.js');

var grape = new grapelib.grape({
		base_directory: __dirname,
		dburi: 'pg://hans:hans123@localhost/test',
		port: 60890
	});

grape.start();

