
var fs = require('fs');
var path = require('path');


var documentStore = function(_opt) {
	this.options = _opt;

	/*
 		Get directory for storing files of type 'filetype', claims
	*/
	this.getDirectory = function(filetype) {
		var dir = app.get('docRepoPath') + '/' + filetype;
		this.makeDirRecursiveSync(dir);
		return dir;
	};

	/*
 		Get relative directory for storing files of type 'filetype'
	*/
	this.getRelativeDirectory = function(filetype) {
		var dir = this.getDirectory(filetype);
		return path.relative(app.get('basePath') + '/../', dir);
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
