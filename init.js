var db_init = require("./lib/db/init");

db_init({
	config: {}, 
	schema_dir: 'db/schema',
	data_directory: 'db/data',
	function_directory: 'db/function'
});
