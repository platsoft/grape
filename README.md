
# Grape

## Setting up a minimal application

* Create a new directory (for example myapp)
* Add the following to your package.json:
```json
{
	"name": "myapp",
	"main": "index.js",
	"dependencies": {
		"ps-grape": "0.0.5"
	}
}
```
* Create your index.js
```

var Grape = require('ps-grape');

var app = new Grape.grape({
	port: 3001,
	base_directory: __dirname
}); 

app.start();

```
* Make sure your npm repository is set to npm.platsoft.net (npm set registry http://npm.platsoft.net:4873)
* execute `npm install` in the created directory
* You can now run `node index.js`



## Serving static files
Pass the option public_directory to the Grape initializer to serve static files from. For example:
```
var Grape = require('ps-grape');

var app = new Grape.grape({
	port: 3001,
	base_directory: __dirname,
	public_directory: __dirname + '/public'
}); 

app.start();

```

## Application directories
A typical skeleton application will contain the following directories:

* db/ - App-specific database functions and structure.
	+ db/schema/ - Database schema
	+ db/function/ - Functions
	+ db/data/
* api/ - App-specific API calls
* public/ - Static files
* doc/ - Documentation
* test/ - Tests
	

## API support
Grape provides built-in API calls. To add API calls to your app, fill the option api_directory in with the directory containing your API calls.

### /session/new
TODO
In: {username, password}
Out: {code, message, status, success}

### /grape/list
List records from a table or view

### /grape/process/start

### /grape/process/list


## DB support
Grape DB 
### Setting up a new database
1. After setting up your app's config.js, run the script script/setup_database.js
2. When providing the -r option, the dataabse will be dropped and created before loading the schema and data


Built-in tables:
### grape.user

### grape.user_role

### grape.access_path


## Session management
Built-in session management is loaded if session_management = true in the grape initializer. When loaded:

* Populate the tables grape."user", grape.user_role, grape.access_path to add new users
* Use the /session/new API call to create a new login

## Logger
TODO

# Reference documentation

## grape.db

## grape.app

### Supported options in grape.app config object
* session_management - Indicates if session management should be loaded or not (true or false, defaults to false)
* api_directory - Load API files from this directory
* port - listen on port (defaults to 3000)
* dburi - database connection options. Must include the following fields: 
	# user - Username to connect with
	# host - The hostname to connect to (or path to pipe)
	# port - The port to connect to (defaults to 5432)
	# database - Name of the database
	# application_name - Application name
* public_directory - load public files from this directory (string)
* db_definition - load database definition and data from this directory (string) The directory structure should look as follows:
	# schema/
	# function/
	# data/
	When the script scripts/setup_database.js is ran all SQL files in the directories listed will be loaded
* sql_dirs - load database definition from directory or directories
* debug - debugging on or off (boolean)
* document_store - Path to system generated documents (string)
* base_directory - Path to base directory (string) If not set it defaults to the parent directory of public_directory
* instances - The number of instances to start (defaults to 1)
* use_https - True to use https. Also need to set options sslkey and sslcert files to use this
* sslkey - file containing private key
* sslcert - file containing public certificate


