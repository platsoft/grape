
var LoginPage = function(bindings) {
	var self = this;
	this.self = self;
	this.bindings = bindings;
	this.viewModel = this;

	this.clickSignin = function() {
		$.post("/session/new", {username: $("#username").val(), password: $("#password").val()}, function(d) { 
			if (d.success == 'true')
			{
				window.Grape.set_session(d);
				Finch.navigate('#/sales');
			}
			else
			{
				alert(JSON.stringify(d));
			}
		});
	};
};


window.Grape.route('[/]login', {
	pageClass: LoginPage,
	file: '/pages/login/login.html'
});


