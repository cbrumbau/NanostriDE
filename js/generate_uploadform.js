// Hide or show HTML elements to generate multiple inputs
var index = 0;
var Dom = {
	get: function(el) {
		if (typeof el === 'string') {
			return document.getElementById(el);
		} else {
			return el;
		}
	},
	add: function(el, dest) {
		var el = this.get(el);
		var dest = this.get(dest);
		dest.appendChild(el);
	},
	remove: function(el) {
		var el = this.get(el);
		el.parentNode.removeChild(el);
	}
	};
	var Event = {
	add: function() {
		if (window.addEventListener) {
			return function(el, type, fn) {
				Dom.get(el).addEventListener(type, fn, false);
			};
		} else if (window.attachEvent) {
			return function(el, type, fn) {
				var f = function() {
					fn.call(Dom.get(el), window.event);
				};
				Dom.get(el).attachEvent('on' + type, f);
			};
		}
	}()
 };
Event.add(window, 'load', function() {
	Event.add('add-upload', 'click', function() {
		var p = document.createElement('p');
		p.setAttribute('id', 'sample'+index);
		var file = document.createElement('input');
		file.setAttribute('type', 'file');
		file.setAttribute('accept', 'text/RCC');
		file.setAttribute('name', 'sampledata'+index);
		file.setAttribute('size', '15');
		var label = document.createElement('label');
		label.appendChild(document.createTextNode('Sample name:\u00A0'));
		var sample_name = document.createElement('input');
		sample_name.setAttribute('type', 'text');
		sample_name.setAttribute('name', 'samplename'+index);
		sample_name.setAttribute('maxlength', '50');
		//~ var remove_link = document.createElement('a');
		//~ remove_link.appendChild(document.createTextNode('Remove'));
		//~ remove_link.setAttribute('href', '#');
		//~ Event.add(remove_link, 'click', function(e) {
			//~ Dom.remove(p);
		//~ });
		label.appendChild(sample_name);
		p.appendChild(file);
		p.appendChild(document.createTextNode('\u00A0\u00A0')); // Add &nbsp;&nbsp; before label
		p.appendChild(label);
		//~ p.appendChild(document.createTextNode('\u00A0\u00A0')); // Add &nbsp;&nbsp; before link
		//~ p.appendChild(remove_link);
		index++;
		$('.remove-upload').show();
		last = p;
		Dom.add(p, 'content');
	});
});
Event.add(window, 'load', function() {
	Event.add('remove-upload', 'click', function() {
		if (index > 0) {
			index--;
			var p = document.getElementById('sample'+index);
			Dom.remove(p);
			if (index == 0) {
				$('.remove-upload').hide();
			}
		}
	});
});
