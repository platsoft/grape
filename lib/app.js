
var express = require('express');
var _ = require('underscore');
var fs = require('fs');

exports = module.exports = function(_o) {
	var app = express();
	
	app.use(express.bodyParser());
	app.use(express.cookieParser());
	
	var options = {
		session_management: false, 
		api_directory: false, 
		apiIgnore: [],
		port: 3000,
		db: null,
		public_directory: false,
		debug: false,
	};
	_.extend(options, _o);

	app.set('db', options.db);

	function setup_session_management()
	{
		// Session management
		app.use(function(req, res, next) {
			var accepts_json = (req.headers.accept.indexOf('application/json') != -1);
			var session_id = req.header('X-SessionID') || req.cookies.SessionID;

			//Do not do session management checking if session id is not set and the request do not want json. We need to check if it is json because it might be a guest API call
			if ((!session_id || session_id == 0) && !accepts_json)
			{
				next();
				return;
			}
			var path = req.app._router.matchRequest(req);

			path = path ? path.path : req.path;
			
			function session_fail () 
			{
				res.set('X-No-Permission', 'true');
				if (req.headers.accept.indexOf('application/json') != -1)
				{
					res.json({error: 'Internal error'});
				} 
				else
				{
					res.send('No permission to access this page. Please ask your manager to contact Platinum Software if you should have access.');
				}
				return;
			}

			db.func('session_check_path_select', session_id, path, req.method, function(err, result) { 
				if (err)
				{
					app.get('logger').session('Could not load access paths for Session ' + session_id + ' against ' + path + ' ' + err);
					session_fail();
					return;
				}

				var ret = result.rows[0];
				if (ret.error_code == 2) // invalid session
				{
					res.clearCookie('SessionID', '/');
				}
				app.get('logger').session((ret.check_path_result ? 'GRANTED' : 'DENIED') + ' ' + session_id + ' ' + path);

				app.set('session', ret);
				app.set('user_access_path', ret.user_role);
				next();
			});
		});
	}

	/**
	 * Loads js files into the application space
	 *
	 * @param {string} relativedirname - Used by loadapifiles() to recursivly loop through the api directories
	 */
	function loadapifiles(dirname, relativedirname) 
	{
		if (relativedirname[relativedirname.length - 1] != '/') relativedirname += '/';

		if (dirname[dirname.length - 1] != '/') dirname += '/';

		//app.get('logger').info('Loading api(s) from: ' + relativedirname);

		if (options.apiIgnore.indexOf(relativedirname) != -1) 
		{
			app.get('logger').info('Ignoring ' + relativedirname + ' - found it in app/apiignore.js');
			return;
		}

		var files = fs.readdirSync(dirname);
		for (var i = 0; i < files.length; i++) 
		{
			var file = files[i];
			var fstat = fs.statSync(dirname + file);
			if (fstat.isFile()) 
			{
				var ar = file.split('.');
				if (ar[ar.length - 1] == 'js' && options.apiIgnore.indexOf(file) === -1) 
				{
					// loads the api module and execute the export function with the app param.
					require(dirname + file)(app);
					//app.get('logger').info("Loaded " + relativedirname + file);
				}
			}
			else if (fstat.isDirectory()) 
			{
				loadapifiles(dirname + '/' + file, relativedirname + file);
			}
		}
	}

	function setup_public_directory(dirname)
	{
		app.use(function(req, res, next) 
		{
			var accepts_json = (req.headers.accept.indexOf('application/json') != -1);
			
			//GET which does not accept JSON 
			if (req.method == 'GET' && !accepts_json && !req.app._router.matchRequest(req))
			{
				//TODO this is insecure, make sure that fileName exists in publicPath
				var fileName = app.get('publicPath') + decodeURI(req.path);
				if (fs.existsSync(fileName)) //public file
				{
					res.sendfile(fileName);
					return;
				} 
				else if (req.path.slice(0, 9) == '/download') //skip the sending of index.html if path is /download (special case)
				{
				} 
				else 	//send index.html to load app (this is for stuff like /search and /policy/:policy_id)
				{
					res.sendfile(app.get('publicPath') + '/index.html');
					return;
				}
			}
			next();
		});
	}

	app.configure(function() {
		
		if (options.session_management)
		{
			setup_session_management();
		}

		// Load built-in API calls
		var builtin_api_dir = __dirname + '/../api/';
		if (options.debug)
		{
			console.log("Loading built-in API calls from " + builtin_api_dir);
		}
		loadapifiles(builtin_api_dir, '');


		if (options.api_directory)
		{
			loadapifiles(options.api_directory, '');
		}
		
		if (options.public_directory)
		{
			app.set('publicPath', options.public_directory);
			setup_public_directory(options.public_directory);
		}
	});

	var http = require('http');
	http.globalAgent.maxSockets = 50;

	var server = app.listen(options.port);

	if (options.debug)
	{
		console.log('Listening on ' + options.port);
	}

	server.timeout = 50000;
	server.on('connection', function(socket) {
		socket.setKeepAlive(true, 1000);
	});

	
	return app;
};


