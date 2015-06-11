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

	
	GrapeApp.prototype.register_dialog = function(name, file, pageClass) {
		this.dialogs[name] = {
			file: file,
			pageClass: pageClass
		};
	};


	//options:
	//	file: HTML file
	//
	//other options recognized in bindings:
	//	onClose: optional callback after dialog has closed
	GrapeApp.prototype.dialog = function(name, bindings) {
		if (!bindings)
			var bindings = {};

		console.log(this.dialogs);

		if (this.dialogs[name])
		{
			var dialog_def = this.dialogs[name];

			var dialog = {};

			var rnd = Math.floor((Math.random() * 10) + 1);
			var dom_dialog_id = 'diag_' + name + '_' + rnd;
			var dom_body_id = 'diagbod_' + name + '_' + rnd;
			var dom_header_id = 'diaghead_' + name + '_' + rnd;

			dialog.dom_dialog_id = dom_dialog_id;
			dialog.dom_body_id = dom_body_id;
			dialog.dom_header_id = dom_header_id;

			var el = $("#container").append(
				'<div class="modal fade" role="dialog" id="' + dom_dialog_id + '">' +
					'<div class="modal-dialog">' +
						'<div class="modal-content">' +
							'<div class="modal-header" id="' + dom_header_id + '"></div>' +
							'<div class="modal-body" id="' + dom_body_id + '"></div>' +
						'</div>' +
					'</div>' +
				'</div>');

			dialog.element = el;

			$("#" + dom_body_id).load(this.dialogs[name].file, function() { 

				console.log("Loaded file into", dom_body_id);

				$("#" + dom_dialog_id).on('hide.bs.modal', function() {
					if (dialog.pageClass.viewModel)
						dialog.data = ko.toJS(dialog.pageClass.viewModel);

					ko.cleanNode(document.getElementById(dom_body_id));
				});  
				$("#" + dom_dialog_id).on('hidden.bs.modal', function() {
					if (bindings.onClose)
					{
						bindings.onClose(dialog.data);
					}
				});  

				$("#" + dom_dialog_id).on('show.bs.modal', function(){
					if (dialog_def.pageClass)
					{
						bindings.dialog_id = dom_dialog_id;
						bindings.dialog_header_id = dom_header_id;
						bindings.dialog_body_id = dom_body_id;
						var pc = new dialog_def.pageClass(bindings);
						
						if (pc.updateData)
							pc.updateData();
						
						if (pc.viewModel)
							ko.applyBindings(pc.viewModel, document.getElementById(dom_body_id)); 

						dialog.pageClass = pc;
					}
				});  
				$("#" + dom_dialog_id).modal('show');  
			});

			return dialog;
		}
	};

	GrapeApp.prototype.show_dialog = GrapeApp.prototype.dialog;

	GrapeApp.prototype.alert = function(options, id) {
		// give it an ID - a div where you want to place it
		if (!options.alert_type) 
		{
			console.error("No alert type given, exiting function. The types are: success, info, warning and danger");
			return;
		}

		if (!options.message) 
		{
			console.error("No message was given, exiting function");
			return;
		}

		if (options.title)
			options.title = '<strong>' + options.title + ' </strong>';
		else
			options.title = "";

		var alert_html = '<div class="alert alert-' + options.alert_type + ' fade in" role="alert"><button type="button" class="close" data-dismiss="alert" aria-hidden="true">×</button>'+ options.title + options.message +'</div>';

		$(id).append(alert_html);
	};

	//options:
	//	either use these options:
	//		file: HTML file
	//		pageClass: optional class of page to load
	//		elementId: DOM element to load the page in and bind knockout to (if applicable). defaults to container
	//	
	//	or give this function:
	//		setup: optional function to call instead of the normal behaviour
	GrapeApp.prototype.route = function(uri, options) {
		var self = this;
		var _options = options;
		var routepage = false;
		var htmlfile = false;
		var element_id = 'container';

		if (options.pageClass)
			var routepage = options.pageClass;
		if (options.file)
			var htmlfile = options.file;
		if (options.elementId)
			element_id = options.elementId;
		
		if (!_options.setup)
		{
			_options.setup = function(bindings, childCallback) {
				if (!localStorage.getItem('session_id'))
				{
					Finch.navigate('#/login');
				}
				
				console.log("Loading " + uri);
				$("#" + element_id).load(htmlfile, function() {
					if (routepage)
					{
						var a = new routepage(bindings);

						self.currentPage = a;
						
						if (a.updateData)
							a.updateData();
						ko.applyBindings(a.viewModel, document.getElementById(element_id));
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


