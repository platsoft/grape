exports = module.exports = function(app) {
	// register the route
	app.get("/maths/sqrt/:value", api_maths_sqrt);
}

function api_maths_sqrt (req, res)
{
	// call the stored procedure for this API call
	res.locals.db.json_call("maths_sqrt", // the name of the PL/pgSQL function
		{value: req.params.value}, // Build the JSON object as input for this function
		null, // Optional callback (not used here)
		{response: res} // Send the response to res
	);
}
