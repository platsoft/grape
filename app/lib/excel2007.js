
var fs = require('fs');
var path = require('path');
var sys = require('sys');
var AdmZip = require('adm-zip');

var libxmljs = require("libxmljs");

var ST_CellType = [
	'b', //boolean
	'n', //number
	'e', //error
	's', //shared string
	'str', //string
	'inlineStr' //inline string
];

function NumberFormat()
{
	this.builtInFormats = {
		0: '',
		1: '0',
		2: '0.00',
		3: '#,##0',
		4: '#,##0.00',

		9: '0%',
		10: '0.00%',
		11: '0.00E+00',
		12: '# ?/?',
		13: '# ??/??',
		14: 'mm-dd-yy',
		15: 'd-mmm-yy',
		16: 'd-mmm',
		17: 'mmm-yy',
		18: 'h:mm AM/PM',
		19: 'h:mm:ss AM/PM',
		20: 'h:mm',
		21: 'h:mm:ss',
		22: 'm/d/yy h:mm',

		37: '#,##0 ;(#,##0)',
		38: '#,##0 ;[Red](#,##0)',
		39: '#,##0.00;(#,##0.00)',
		40: '#,##0.00;[Red](#,##0.00)',

		44: '_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
		45: 'mm:ss',
		46: '[h]:mm:ss',
		47: 'mmss.0',
		48: '##0.0E+0',
		49: '@',

		27: '[$-404]e/m/d',
		30: 'm/d/yy',
		36: '[$-404]e/m/d',
		50: '[$-404]e/m/d',
		57: '[$-404]e/m/d',

		59: 't0',
		60: 't0.00',
		61: 't#,##0',
		62: 't#,##0.00',
		67: 't0%',
		68: 't0.00%',
		69: 't# ?/?',
		70: 't# ??/??',
	};
}

function CellStyle()
{
	
}

function CellFormattingRecord()
{
	this.numFmtId = 0;
	this.fontId = 0;
	this.fillId = 0;
	this.borderId = 0;
	this.xfId = 0;
}

function CellData()
{
	var contents = null;
}

function Cell() 
{
	this.metadataidx = ''; //cm
	this.reference = ''; //r (cell location)
	this.styleidx = ''; //s
	this.datatype = ''; //t - ST_CellType
	this.valuemetadataidx = ''; //vm

	this.column = '';

	this.data = new CellData();

	this.row = null;

	this.printData = function()
	{
		console.log(this.reference + " [" + this.getValue() + "]");
	}
	this.printFormattedData = function()
	{
		console.log(this.reference + " [" + this.getFormattedValue() + "]");
	}


	this.getValue = function()
	{
		if (!this.datatype)
			return this.data.contents;
		switch (this.datatype)
		{
			case 's':
				return this.row.worksheet.document.SharedStrings[this.data.contents];
			case 'str':
				return this.data.contents;
			case '':
				return this.data.contents;
			case 'n':
				return parseFloat(this.data.contents);
			case 'b':
				return this.data.contents == '0' ? 'FALSE' : 'TRUE';
			default:
				return this.data.contents;
		}
	}

	this.getFormattedValue = function()
	{
		var v = this.getValue();
		if (!this.styleidx || this.styleidx == '')
			return v;
	//	console.log("cell styleidx is " + this.styleidx);

		var xf = this.row.worksheet.document.FormattingRecords[this.styleidx];
		var nf = this.row.worksheet.document.NumberFormat.builtInFormats[xf.numFmtId];

		if (nf == "GENERAL" || nf == "")
			return v;
		
		var ar = nf.match(/^(\[\$[A-Z]*-[0-9A-F]*\])*[hmsdy]/i);
		if (ar && ar.length > 0)
		{
			var base = 25569;
			var i = parseInt(v);

			if (isNaN(i))
				return v;

			var days = i - base;
			var secs = days * 86400000;
			var d = new Date();
			d.setTime(secs);
			var ret = d.getFullYear() + '/' + (d.getMonth()+1) + '/' + d.getDate();
			//var ret = nf;
			//ret = ret.replace(/[Y]{1,4}/i, d.getFullYear());
			//ret = ret.replace(/[M]{1,2}/i, d.getMonth());
			//ret = ret.replace(/[D]{1,2}/i, d.getDate());
			return ret;
		}

		return v;
	}
}

function Row()
{
	this.rownumber = -1;
	this.cells = [];
	this.worksheet = null;

	this.printCells = function()
	{
		for (var i = 0; i < this.cells.length; i++)
		{
			var cell = this.cells[i];
			cell.printData();
		}
	}
	this.printFormattedCells = function()
	{
		for (var i = 0; i < this.cells.length; i++)
		{
			var cell = this.cells[i];
			cell.printFormattedData();
		}
	}


	this.getCellValueAt = function(ref) {
		for (var i = 0; i < this.cells.length; i++)
		{
			if (this.cells[i].reference == ref)
			{
				return this.cells[i].getValue();
			}
		}
		return '';
	};

	this.getFormattedCellValueAt = function(ref) {
		for (var i = 0; i < this.cells.length; i++)
		{
			if (this.cells[i].reference == ref)
			{
				return this.cells[i].getFormattedValue();
			}
		}
		return '';
	};


	this.getAllCellValues = function() {
		var ret = {};
		for (var i = 0; i < this.cells.length; i++)
		{
			var reference = this.cells[i].reference;
			reference = reference.replace(/[0-9]+/g, '');
			ret[reference] = this.cells[i].getValue();
		}
		return ret;
	};
}

function WorkSheet()
{
	this.name = '';
	this.sheetId = -1;
	this.relId = -1;
	this.rows = [];
	this.highestColumn = 'A';
	this.highestRow = 0;
	this.document = null;
	this.printRows = function()
	{
		for (var i = 0; i < this.rows.length; i++)
		{
			var row = this.rows[i];
			console.log("Row " + row.rownumber);
			row.printCells();
		}
	};

	this.readRows = function(cb) {
		for (var i = 0; i < this.rows.length; i++)
		{
			var row = this.rows[i];
			cb(row);
		}
	};
}

function Document()
{
	this.workSheets = [];
	this.workSheetNames = [];
	this.SharedStrings = [];
	this.NumberFormat = new NumberFormat();
	this.CellStyles = [];
	this.FormattingRecords = [];

	this.getWorkSheetByName = function(n) {
		for (var i = 0; i < this.workSheets.length; i++)
		{
			if (this.workSheets[i].name == n)
				return this.workSheets[i];
		}
		return null;
	};

	this.getWorkSheetByRelId = function(n) {
		for (var i = 0; i < this.workSheets.length; i++)
		{
			if (this.workSheets[i].relId == n)
				return this.workSheets[i];
		}
		return null;
	};

}

function Excel2007Reader(xlsfilename, doc)
{
	this.xlsfilename = xlsfilename;
	this.document = doc;
	this.dir = '';

	this.readRelationships = function(filename)
	{
		if (!fs.existsSync(filename))
			return;

		console.log("Reading relationships from " + filename);

		var dir = path.dirname(filename);
		dir = path.dirname(dir);
		var str = fs.readFileSync(filename);

		var doc = libxmljs.parseXmlString(str);

		var rels = {
			"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument": [],
			"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings": [],
			"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles": [],
			"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet": [],
		};

		var children = doc.childNodes();
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.attr('Id'))
				var relId = el.attr('Id').value();
			if (el.attr('Type'))
				var type = el.attr('Type').value();
			if (el.attr('Target'))
				var target = el.attr('Target').value();
			console.log("target [" + target + "] type [" + type + "]");
			var targetfilename = dir + "/" + target;

			if (!rels[type])
			{
				console.log("Unknown file type " + type);
				rels[type] = [];
			}
			rels[type].push({relId: relId, target: target, targetfilename: targetfilename});

			if (type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument")
			{
				this.readOfficeDocument(targetfilename);
			}
			if (type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet")
			{
				var w = this.document.getWorkSheetByRelId(relId);
				if (w == null)
				{
					console.log("Could not read worksheet with relId " + relId);
				}
				this.readWorkSheet(targetfilename, w);
			}
			if (type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles")
			{
				this.readStylesFile(targetfilename, this.document);
			}

			var targetrels = path.dirname(targetfilename) + "/_rels/" + path.basename(targetfilename) + ".rels";
			this.readRelationships(targetrels);
		}

		var ar = rels["http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"];
		for (var i = 0; i < ar.length; i++)
		{
			var o = ar[i];
			this.readSharedStrings(o.targetfilename);
		}
	}

	this.readSharedStrings = function(filename)
	{
		console.log("Reading " + filename);
		var str = fs.readFileSync(filename);
		var doc = libxmljs.parseXmlString(str);

		var children = doc.childNodes();
		
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.name() == "si")
			{
				var ar = el.childNodes();
				for (var j = 0; j < ar.length; j++)
				{
					if (ar[j].name() == "t")
					{
						this.document.SharedStrings.push(ar[j].text());
					}
					else
					{
						console.log("Unknown element " + ar[j].name() + " in readSharedStrings 2");
					}
				}
			}
			else
			{
				console.log("Unknown element " + el.name() + " in readSharedStrings");
			}
		}

	}

	this.readSheetData = function(element, sheet)
	{
		var rows = [];
		var children = element.childNodes();
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.name() == "row")
			{
				var row = new Row();
				row.worksheet = sheet;
				row.rownumber = el.attr('r');
				var cols = el.childNodes();
				for (var j = 0; j < cols.length; j++)
				{
					var col = cols[j];
					var type = '';
					if (col.attr('t') != null)
						type = col.attr('t').value();
					var r = col.attr('r').value();
					var cell =  new Cell();
					cell.reference = r;
					cell.datatype = type;
					cell.row = row;
					if (col.attr('s') != null)
						cell.styleidx = col.attr('s').value();

					var ar = col.childNodes();
					if (ar.length > 0)
					{
						if (ar[0].name() == "v")
						{
							cell.data.contents = ar[0].text();
						}
						else
						{
							console.log("Unknown element " + ar[0].name() + " in readSheetData");
						}
					}
					else
					{
						//console.log("Error in this.readSheetData " + col);
					}
					row.cells.push(cell);
				}
				sheet.rows.push(row);
			}
		}
	}

	this.readWorkSheet = function(filename, w)
	{
		console.log("Reading worksheet " + filename);
		var str = fs.readFileSync(filename);
		var doc = libxmljs.parseXmlString(str);

		var children = doc.childNodes();
		
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.name() == "sheetData")
			{
				this.readSheetData(el, w);
			}
		}
		
	}

	this.readOfficeDocument = function(filename)
	{
		console.log("reading " + filename);
		var str = fs.readFileSync(filename);
		var doc = libxmljs.parseXmlString(str);

		this.document.workSheets = [];

		var relationships = {};
		var children = doc.childNodes();
		
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.name() == "sheets")
			{
				var sheets_el = el.childNodes();
				for (var j = 0; j < sheets_el.length; j++)
				{
					var sheet_el = sheets_el[j];
					if (sheet_el.name() == "sheet")
					{
						var sheetrelid = sheet_el.attr('id').value();
						var w = new WorkSheet();
						w.document = this.document;
						w.name = sheet_el.attr('name').value();
						w.sheetId = sheet_el.attr('sheetId').value();
						w.relId = sheetrelid;

						this.document.workSheets.push(w);
						//console.log("adding worksheet [" + w.name + "]  at idx " + w.sheetid);
						this.document.workSheetNames.push(w.name);
					}
				}
			}
		}
	}

	this.readStylesFile = function(filename) 
	{
		console.log("reading " + filename);
		var str = fs.readFileSync(filename);
		var doc = libxmljs.parseXmlString(str);

		var children = doc.childNodes();
		
		for (var i = 0; i < children.length; i++)
		{
			var el = children[i];
			if (el.name() == "numFmts")
			{
				var num_fmts_el = el.childNodes();
				for (var j = 0; j < num_fmts_el.length; j++)
				{
					var numfmt_el = num_fmts_el[j];
					if (numfmt_el.name() == "numFmt")
					{
						var numFmtId = numfmt_el.attr('numFmtId').value();
						var formatCode = numfmt_el.attr('formatCode').value();
						this.document.NumberFormat.builtInFormats[numFmtId] = formatCode;
					}
					else
						console.log("numFmts unknown " + el.name());
				}
			}
			else if (el.name() == "cellXfs")
			{
				var child_els = el.childNodes();
				for (var j = 0; j < child_els.length; j++)
				{
					var child_el = child_els[j];
					if (child_el.name() == "xf")
					{
						var n = new CellFormattingRecord();
						n.numFmtId = child_el.attr('numFmtId').value();
						n.fontId = child_el.attr('fontId').value();
						n.fillId = child_el.attr('fillId').value();
						n.borderId = child_el.attr('borderId').value();
						this.document.FormattingRecords.push(n);
					}
					else
						console.log("cellXfs unknown " + child_el.name());
				}

				
			}
			else
			{
				console.log(el.name());
			}
		}
	}

	this.openFile = function() 
	{
		this.dir = './zipcontent/';
		var zip = new AdmZip(this.xlsfilename);
		zip.extractAllTo(this.dir, true);
		this.readRelationships(this.dir +  "/_rels/.rels");

		
	}
}


exports.Excel2007Reader = Excel2007Reader;
exports.Document = Document;


