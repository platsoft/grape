var app;

exports = module.exports = function(_app) {
	app = _app;

	// register the route
	app.get("/download/user_info/:user_id", api_download_user_pdf);
}

function api_download_user_pdf(req, res)
{
	app.get('pdfgenerator').generate_and_stream_xml({
		res: res,
		funcName: 'generate_user_xml',
		funcParams: [req.params.user_id],
		documentType: 'document_type',
		baseFileName: 'user_' + req.params.user_id,
		xslName: 'user_info.xsl'
	});
}



