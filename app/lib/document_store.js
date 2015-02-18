
var fs = require('fs');
var path = require('path');

/**
 * Options: { 	document_store Directory of document store
 * 		base_directory Base directory of app
 * 	}
 *
 */
var documentStore = function(_opt) {
	this.options = _opt;
	var self = this;
	this.self = self;

	if (!self.options.document_store || !self.options.base_directory)
	{
		console.log("This ain't right");
	}

	/*
 		Get directory for storing files of type 'filetype', claims
		Returns full path
	*/
	this.getDirectory = function(filetype) {
		var dir = self.options.document_store + '/' + filetype;
		this.makeDirRecursiveSync(dir);
		return dir;
	};

	/*
 		Get relative directory for storing files of type 'filetype'
	*/
	this.getRelativeDirectory = function(filetype) {
		var dir = this.getDirectory(filetype);
		return path.relative(self.options.base_directory, dir);
	};

	/*
 		Copies a file from path to repo dir for filetype
	*/
	this.saveFile = function(filetype, currentpath, filename) {
		var dir = self.getDirectory(filetype);
		if (!filename)
		{
			var ar = currentpath.split('/');
			var filename = ar[ar.length-1];
		}
		var newfilename = dir + '/' + filename;
		fs.writeFileSync(newfilename, fs.readFileSync(currentpath));
		return dir;
	};


	this.makeDirRecursiveSync = function(dir) {
		var ar = dir.split('/');
		var curr = '';
		for (var i = 0; i < ar.length; i++)
		{
			curr += '/' + ar[i];
			if (!fs.existsSync(curr))
				fs.mkdirSync(curr);
			if (!fs.existsSync(curr))
				return false;
		}
		return true;
	};
};

exports = module.exports = documentStore;
