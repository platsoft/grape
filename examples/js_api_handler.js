exports = module.exports = function(app) {
	// register the route
	app.get("/maths/sqrt/:value", api_maths_sqrt);
}

function api_maths_sqrt (req, res)
{
	try {
		var v = parseFloat(req.param.value);
		v = Math.sqrt(v);
		res.send({"status":"OK", "result": v});
	} catch (e) {
		res.send({"status":"ERROR", "error": e});
	}
}
