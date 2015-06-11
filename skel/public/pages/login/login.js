
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

	this.clickNewuser = function() {
		var dialog = window.Grape.dialog('newuser', {
			onClose: function(data) {
				if (data.email)
				{
					var msg = 'Your new user registration has been received. A confirmation email will be sent to ' + data.email;
					Grape.alert({alert_type: 'info', message: msg}, '#div_login_alerts');
				}
			}
		});
	};
};


window.Grape.route('[/]login', {
	pageClass: LoginPage,
	file: '/pages/login/login.html'
});


