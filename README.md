
# Begin

## Setting up a new application

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
* npm update
* Create your index.js
```
	var grape = require('grape');
	var app = grape.app({
		port: 3001
	});
```

# API support


# grape.app

## Support options in grape.app
	* session_management - Indicates where session management should be loaded or not (true or false, defaults to false)
	* api_directory - Load API files from this directory
	* apiIgnore - Array containing list of API files to ignore
	* port - listen on port (defaults to 3000)
	* db - instance of grape.db
	* public_directory - load public files from this directory



