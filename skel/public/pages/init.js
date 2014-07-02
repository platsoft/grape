$(function() {
	Finch.route('/', function(bindings, childCallback) { 
		console.log("Loading /");

		$(document.body).load('/pages/init.html', function() {
			console.log("Loading navbar");
			$("#menu").load('/pages/navbar.html', childCallback);
		});
	});
});
function logout() {
	localStorage.clear();
	Finch.navigate('/login');
};

