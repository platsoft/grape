"use strict";

const si = require('systeminformation');
const async = require('async');

exports = module.exports = function() {

	return function (req, res) {
		async.parallel([
			function(next) {
				si.fsStats(function(d) { 
					next(null, {'fs': {
						rx: d.rx,
						wx: d.rx
					}});
				});
			},
			function(next) {
				si.disksIO(function(d) { 
					next(null, {'disk': {
						ior: d.rIO,
						iow: d.wIO
					}});
				});
			},
			function(next) {
				si.networkInterfaces(function(d) { 
					var ifaces = d;
					var count_done = 0;

					ifaces.forEach(function(iface) {
						si.networkStats(iface, function(d) {
							
							iface['st'] = {
								operstate: d.operstate,
								rx: d.rx,
								wx: d.wx
							};

							count_done++;
							if (count_done >= ifaces.length)
								next(null, {'net': ifaces});
						});
					});

				});
			},
			function(next) {
				si.currentLoad(function(d) { 
					next(null, {'load': d});
				});
			},
		], function(err, results) {
			var obj = {};
			for (var i = 0; i < results.length; i++)
			{
				var keys = Object.keys(results[i]);
				if (keys[0])
					obj[keys[0]] = results[i][keys[0]];
			}

			res.json(obj).end();
		});
	};
}

