"use strict";

$(function() {
	var GrapeApp = function() { 
		this.models = {};
		this.pages = {};
		this.dialogs = {};
	}
	
	GrapeApp.prototype.init = function() {
		$.getScript('/download_public_js_files', function(data, textStatus, jqXHR) {
			Finch.listen();

			if (!localStorage.getItem('session_id'))
			{
				Finch.navigate('#/login');
			}
		});
	};

	GrapeApp.prototype.set_session = function(session) {
		localStorage.setItem('session_id', session.session_id);
	};

	//options:
	//	file: HTML file
	GrapeApp.prototype.show_dialog = function(name, object, options) {
		if (this.dialogs[name])
		{
			var dialog = this.dialogs[name];
			var el = $("#container").append('<div class="modal" role="dialog" id="tmp_dialog"></div>');

			$("#tmp_dialog").load(this.dialogs[name].file,function() { 
				$("#tmp_dialog").on('hide.bs.modal', function(){
					ko.cleanNode(document.getElementById('tmp_dialog'));
				});  
				$("#tmp_dialog").on('show.bs.modal', function(){
					if (dialog.pageClass)
					{
						var pc = new dialog.pageClass(object);
						if (pc.viewModel)
							ko.applyBindings(pc.viewModel, document.getElementById('tmp_dialog'));
					}
				});  
				$("#tmp_dialog").modal('show');  
			});
		}
	};

	GrapeApp.prototype.alert = function(options, id) {
		// give it an ID - a div where you want to place it
		if(!options.alert_type) 
		{
			console.error("No alert type given, exiting function. The types are: success, info, warning and danger");
			return;
		}

		if(!options.message) 
		{
			console.error("No message was given, exiting function");
			return;
		}

		if(options.title)
			options.title = '<strong>' + options.title + ' </strong>';
		else
			options.title = "";

		var alert = '<div class="alert alert-' + options.alert_type + ' fade in"><button type="button" class="close" data-dismiss="alert" aria-hidden="true">×</button>'+ options.title + options.message +'</div>';

		$(id).append(alert);
	};

	//options:
	//	file: HTML file
	//	pageClass: class of page to load
	GrapeApp.prototype.route = function(uri, options) {
		var self = this;
		var _options = options;
		var routepage = false;
		var htmlfile = false;


		if (options.pageClass)
			var routepage = options.pageClass;
		if (options.file)
			var htmlfile = options.file;
		
		if (!_options.setup)
		{
			_options.setup = function(bindings, childCallback) {
				if (!localStorage.getItem('session_id'))
				{
					Finch.navigate('#/login');
				}
				
				console.log("Loading " + uri);
				$("#container").load(htmlfile, function() {
					if (routepage)
					{
						var a = new routepage(bindings);

						self.currentPage = a;
						
						if (a.updateData)
							a.updateData();
						ko.applyBindings(a.viewModel, document.getElementById('container'));
					}
					childCallback(); 
				});
			}
		}

		if (!_options.teardown)
		{
			_options.teardown = function(bindings, next) {
				console.log("TEARDOWN " + uri);
				ko.cleanNode(document.getElementById('container'));
				next();
			}
		}


		Finch.route(uri, _options); 
	};

	// TODO: replace with get_session
	GrapeApp.prototype.getCookie = function(cname) {
		var name = cname + "=";
		var ca = document.cookie.split(';');
		for(var i=0; i<ca.length; i++) {
			var c = ca[i].trim();
			if (c.indexOf(name) == 0) 
				return c.substring(name.length,c.length);
		}
		return "";
	};

	window.GrapeApp = GrapeApp;

	window.Grape = new GrapeApp();
	window.Grape.init();

	jQuery["postJSON"] = function( url, data, callback, datatype ) {
		if (!datatype)
			var datatype = 'json';

		if (typeof data == 'object')
			var str = JSON.stringify(data);
		else
			var str = data;

		return jQuery.ajax({
			url: url,
			type: "POST",
			contentType:"application/json; charset=utf-8",
			dataType: datatype,
			data: str,
			success: callback
		});
	};
	ko.bindingHandlers.currency = {
		symbol: ko.observable('R'),
		update: function(element, valueAccessor, allBindingsAccessor){
			return ko.bindingHandlers.text.update(element,function(){
				var value = +(ko.utils.unwrapObservable(valueAccessor()) || 0);

				if(ko.utils.unwrapObservable(allBindingsAccessor().symbol) === undefined)
					var symbol = ko.bindingHandlers.currency.symbol()
				else
					var symbol = ko.utils.unwrapObservable(allBindingsAccessor().symbol);

				return symbol + value.toFixed(2).replace(/(\d)(?=(\d{3})+\.)/g, "$1,");
			});
		}
	};

	

	ko.bindingHandlers.dateString = {
		update: function(element, valueAccessor, allBindingsAccessor, viewModel) {
			var value = valueAccessor();
			var allBindings = allBindingsAccessor();
			
			var valueUnwrapped = ko.utils.unwrapObservable(value);
			
			if(valueUnwrapped)
				$(element).text(valueUnwrapped.slice(0,10));
			else
				return;
		}
	};

	ko.bindingHandlers.dateTimeString = {
		update: function(element, valueAccessor, allBindingsAccessor, viewModel) {
			var value = valueAccessor();
			var allBindings = allBindingsAccessor();
			
			var valueUnwrapped = ko.utils.unwrapObservable(value);
			
			if(valueUnwrapped)
				$(element).text(valueUnwrapped.slice(0,16));
			else 
				return;
		}
	};

	ko.bindingHandlers.returnKey = {
		init: function(element, valueAccessor, allBindingsAccessor, viewModel) {
			ko.utils.registerEventHandler(element, 'keydown', function(evt) {
				if (evt.keyCode === 13) {
					evt.preventDefault();
					valueAccessor().call(viewModel);
				}
			});
		}
	};
});


