var TemplateModel = function(page) 
{
	var self = this;
	this.self = self;

    this.total = ko.observable(0);
    this.offset = ko.observable(0);
    this.limit = ko.observable(10);
    this.page_number = ko.observable(1);
    this.total_pages = ko.observable(1);
    this.start_index = ko.observable(1);

	this.records = ko.observableArray();
	this.page = page;
}

var TemplatePage = function(bindings) {
	var self = this;
	this.self = self;
	this.bindings = bindings;
	this.viewModel = new TemplateModel(this);

	this.updateData = function(filter) {
		//ko.mapping.fromJS(data, {}, self.viewModel);
	};
}


window.Grape.route('[/]template', {
	pageClass: TemplatePage,
	file: '/pages/template.html'
});


