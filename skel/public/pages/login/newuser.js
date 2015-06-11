
var NewUser = function(page) {
	var self = this;
	this.self = self;
	this.page = page;
	this.username = ko.observable();
	this.email = ko.observable();

	this.saveAndClose = function() {
		self.page.closeDialog();
	};
};

var NewUserDialog = function(bindings) {
	var self = this;
	this.self = self;
	this.bindings = bindings;
	this.viewModel = new NewUser(this);

	this.closeDialog = function() {

		// Register new user here

		$("#" + self.bindings.dialog_id).modal('hide');
	}
};


window.Grape.register_dialog('newuser', '/pages/login/newuser.html', NewUserDialog);





