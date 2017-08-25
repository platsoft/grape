
var gutil;
var fs = require('fs');
var util = require('util');
var exec = require('child_process').exec;
var path = require('path');

function PDFGenerator(app)
{
	var self = this;
	this.self = self;

	var grapelib = require(__dirname + '/../index.js');
	this.logger = app.get('logger');
	this.site_name = null;
	this.xsl_directory = null;

	if (app.get('config').site_name)
		this.site_name = app.get('config').site_name;

	if (app.get('config').xsl_directory && fs.existsSync(app.get('config').xsl_directory))
	{
		this.xsl_directory = app.get('config').xsl_directory;
		app.get('logger').info('app', 'XSL directory set to ' + this.xsl_directory);
	}
	else
	{
		app.get('logger').warn('app', 'No XSL directory defined (or directory does not exist). You will not be able to generate PDF documents');
	}

	this.app = app;

	/**
	 * 1. Transform xmlFile with xslFile into fopFile
	 * 2. 
	 *
	 * Options: 
	 * {
	 * 	app
	 * 	xmlFile
	 * 	pdfFile
	 * 	logFile
	 *	fopFile
	 *	xslFile
	 *	success: callback
	 * }
	 */
	this.create_pdf_from_xml = function(_o) {
		var o = _o;

		var dirname = path.dirname(o.xslFile);

		var fopPath = o.app.get('config').fop;

		if (!fopPath)
			fopPath = '/opt/fop-1.1/fop';

		var cmd = ['xsltproc', 
			'--stringparam', 'xsldirname', '"' + dirname + '"',
			'-o', '"' + o.fopFile + '"',  
			'"' + o.xslFile + '"', 
			'"' + o.xmlFile + '"'].join(' ');

		exec(cmd, function(error, stdout, stderr) {
			
			if (error)
			{
				self.app.get('logger').error('app', 'Command failed: ' + cmd + ' (' + error.message + ')');
				fs.writeFileSync(o.logFile, stderr);
				o.success(o);
				return;
			}

			var cmd = [fopPath, '"' + o.fopFile + '"', '-pdf', '"' + o.pdfFile + '"'].join(' ');

			exec(cmd, function(error, stdout, stderr) {
				if (error)
				{
					self.app.get('logger').error('app', 'Command failed: ' + cmd + ' (' + error.message + ')');
					fs.writeFileSync(o.logFile, stderr);
				}
				else
					fs.writeFileSync(o.logFile, stdout);
				o.success(o);
			});
		});
	};

	/**
	 *  1. Calls DB function funcName with parameters funcParams. funcName should return XML
	 *  2. Transform XML using the XSL file xslName (config.xsl_directory + '/' + [site_name + '/'] + xslName) to get FOP output
	 *  3. Generate PDF from FOP output. Store PDF in (documentStore + '/' + documentType + '/' + YEAR + '/' + MONTH + '/' + baseFileName.pdf
	 *  4. Stream this file to res
	 *
	 *  funcName TEXT SQL function name
	 *  funcParams ARRAY
	 *  res
	 *  documentType
	 *  baseFileName
	 *  xslName TEXT XSL stylesheet name
	 */
	this.generate_and_stream_xml = function(o) {
		var app = self.app;
		var res = o.res;
		var ds = app.get('document_store');
		var dir = ds.getDirectory('documents/' + o.documentType);
		
		var base_file = o.baseFileName;

		var xml_name = dir + "/" + base_file + '.xml';
		var fo_name = dir + "/" + base_file + '.fop';
		var pdf_name = dir + "/" + base_file + '.pdf';
		var log_name = dir + "/" + base_file + '.log';

		var xsl_path = [self.xsl_directory, self.site_name, o.xslName].join('/');
		if (!fs.existsSync(xsl_path))
		{
			xsl_path = [self.xsl_directory, o.xslName].join('/');
			if (!fs.existsSync(xsl_path))
			{
				app.get('logger').error('app', 'XSL file could not be found (' + o.xslName + ')');
				res.send('Error: XSL file (' + o.xslName + ') could not be found').end();
				return false;
			}
		}

		var parami = [];
		for (var i = 1; i <= o.funcParams.length; i++)
			parami.push('$' + i);

		var callFunc = o.funcName;
		callFunc += '(' + parami.join(',') + ') x';

		var qry = res.locals.db.query("SELECT * FROM " + callFunc, o.funcParams);

		qry.on('error', function(err) {
			var msg = err.hint || '';
			if (err.code == '42883')
			{
				msg = 'The XML generator function (' + callFunc + ') does not exist';
			}
			msg = msg + err.toString();

			self.app.get('logger').error('db', 'Error while generating PDF: ' + msg + '(at ' + (err.internalQuery || '') + ')');
			res.status(500).send('Error: ' + msg);
		});

		qry.on('row', function(xml) {
			var dataxml = xml.x;
			fs.writeFileSync(xml_name, dataxml);
			var xslfile = xsl_path;

			self.create_pdf_from_xml({
				app: app,
				xmlFile: xml_name,
				pdfFile: pdf_name,
				logFile: log_name,
				fopFile: fo_name,
				xslFile: xslfile,
				baseFile: base_file,
				success: function(o) {
					if (fs.existsSync(o.pdfFile))
					{
						var buf = fs.readFileSync(o.pdfFile);
						res.set('Content-Type', 'application/pdf'); 
						res.set('Content-Disposition', 'inline; filename="' + o.baseFile + '.pdf"');
						res.status(200).send(buf); 
					}
					else
					{
						var buf = fs.readFileSync(o.logFile);
						res.set('Content-Type', 'plain/text'); 
						res.set('Content-Disposition', 'inline; filename="' + o.baseFile + '.log"'); 
						res.status(201).send(buf); 
					}

				}
			});
			
		});
	};


}

module.exports.PDFGenerator = PDFGenerator;

