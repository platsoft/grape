"use strict";

const si = require('systeminformation');
const async = require('async');

exports = module.exports = function(app) {

/**
 * @url /grape/system_info
 * @method GET
 * @desc Gets system info and status
 * @return 
 */
	app.get('/grape/system_info', system_info);

/**
 * @url /grape/perf
 * @method GET
 * @desc Gets system performance metrics
 * @return 
 */
	app.get('/grape/perf', perf_stats);

};

function system_info(req, res)
{

	async.parallel([
		function(next) {
			si.cpu(function(d) { 
				next(null, {'cpu': d});
			});
		},
		function(next) {
			si.cpuTemperature(function(d) { 
				next(null, {'cputemp': d});
			});
		},
		function(next) {
			si.mem(function(d) { 
				var memusage = parseInt((d.total - d.available) / d.total * 100);
				var used = d.total - d.available;
				var obj = {
					memusage: memusage,
					available: Math.round(parseFloat(d.available/1024/1024/1000), 2) + 'GB',
					used: Math.round(parseFloat(used/1024/1024/1000), 2) + 'GB',
					total: Math.round(parseFloat(d.total/1024/1024/1000), 2) + 'GB',
					swaptotal: d.swaptotal,
					swapused: d.swapused
				};
				next(null, {'mem': obj});
			});
		},
		function(next) {
			si.osInfo(function(d) { 
				next(null, {'os': d});
			});
		},
		function(next) {
			si.fsSize(function(d) { 
				next(null, {'fs': d});
			});
		},
		function(next) {
			si.blockDevices(function(d) { 
				next(null, {'blockdev': d});
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

		obj['time'] = si.time();
		res.json(obj).end();
	});
}

function perf_stats (req, res)
{
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

}

