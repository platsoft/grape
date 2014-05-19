
module.exports = {
	api_directory: __dirname + '/api',
	dburi: { user: 'myapp', host: '/tmp', database: 'myapp', application_name: 'myapp' },
	db_definition: __dirname + '/db',
	port: 3001,
	public_directory: __dirname + '/public',
	debug: true,
	session_management: false
};

