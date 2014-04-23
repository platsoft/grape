
# Begin

## Setting up a minimal application

* Create a new directory (for example myapp)
* Add the following to your package.json:
```json
{
	"name": "myapp",
	"main": "index.js",
	"dependencies": {
		"grape": "git+ssh://git@mail.platsoft.net:grape.git#master"
	}
}
```
* execute `npm update` in the created directory
* Create your index.js
```
	var grape = require('grape');
	var app = grape.app({
		port: 3001
	});
```
* You can now run `node index.js`

## Serving static files
Pass the option public_directory to the Grape initializer to serve static files from. For example:
```
	var grape = require('grape');
	var app = grape.app({
		public_directory: __dirname + '/public',
		port: 3001
	});
```

## Application directories
A typical skeleton application will contain the following directories:
	* db/ - App-specific database functions and structure
	* api/ - App-specific API calls
	* public/ - Static files
	

## API support
Grape provides built-in API calls. To add API calls to your app, fill the option api_directory in with the directory containing your API calls.

## DB support
Grape DB 
TODO

## Session management
TODO

## Logger
TODO

# Reference documentation

## grape.db

## grape.app

### Supported options in grape.app
	* session_management - Indicates where session management should be loaded or not (true or false, defaults to false)
	* api_directory - Load API files from this directory
	* port - listen on port (defaults to 3000)
	* dburi - database connection options. Must include the following fields: 
		# user - Username to connect with
		# host - The hostname to connect to (or path to pipe)
		# database - Name of the database
		# application_name - Application name
	* public_directory - load public files from this directory (string)
	* db_definition - load database definition and data from this directory (string)
	* debug - debugging on or off (boolean)



