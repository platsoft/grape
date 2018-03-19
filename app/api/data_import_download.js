
module.exports = function()
{
	function api_data_import_download(req, res)
	{
		var filename = req.params.filename;
		var extension = filename.match(/\.[^\.]*$/)
		var data_import_id = req.params.data_import_id;
		var ds = req.app.get('document_store');
		var location = ds.getDirectory('dimport');
		location = [location, 'data_import_'+data_import_id+extension].join('/');
		res.download(location, filename);
	}

	return api_data_import_download;
}

