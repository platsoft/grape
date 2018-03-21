
module.exports = function() { 
	return function(req, res, next) { 
		res.json({}).end();
	};
};

