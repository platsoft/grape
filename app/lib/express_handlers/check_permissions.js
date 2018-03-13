
module.exports = function() {

	function check_staticfile_permissions(req, res, next) 
	{
		var handler = req.handler;

		var public_directory = handler.public_directory;

		next();
	}

	return function(req, res, next) {
		if (!req.handler)
		{
			res.status(500).end();
			return;
		}

		if (req.handler.handler_type == 'staticfile')
		{
			check_staticfile_permissions(req, res, next);
		}
	};
};

