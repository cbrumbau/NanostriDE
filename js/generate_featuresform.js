// Create HTML elements to generate multiple feature radio inputs
function set_features(feature_num, name_value, group_array) {
	// Set name array by name value
	var name_array = [];
	if (name_value == "default") {
		name_array = all_default_label;
	} else if (name_value == "samplename") {
		name_array = all_sample_name;
	} else if (name_value == "filename") {
		name_array = all_filename;
	}
	var l = name_array.length;
	// Remove all previous features
	var old_table = document.getElementById('datalabeltable');
	if (old_table) {
		old_table.parentNode.removeChild(old_table);
	}
	// Add new features
	var table = document.createElement('table');
	table.setAttribute('id', 'datalabeltable');
	// Fill in table
	for (var idx = 0; idx < l; idx++) {
		var tr = document.createElement('tr');
		if (feature_num == 2) {
			var td_1 = document.createElement('td');
			td_1.appendChild(document.createTextNode(name_array[idx]+':'));
			var td_2 = document.createElement('td');
			var radio_1 = document.createElement('input');
			radio_1.setAttribute('type', 'radio');
			radio_1.setAttribute('name', 'datalabel'+(idx+1));
			radio_1.setAttribute('value', 0);
			td_2.appendChild(document.createTextNode('Control\u00A0'));
			var td_3 = document.createElement('td');
			var radio_2 = document.createElement('input');
			radio_2.setAttribute('type', 'radio');
			radio_2.setAttribute('name', 'datalabel'+(idx+1));
			radio_2.setAttribute('value', 1);
			td_3.appendChild(document.createTextNode('Case\u00A0'));
			var td_4 = document.createElement('td');
			var radio_3 = document.createElement('input');
			radio_3.setAttribute('type', 'radio');
			radio_3.setAttribute('name', 'datalabel'+(idx+1));
			radio_3.setAttribute('value', 'exclude');
			td_4.appendChild(document.createTextNode('Exclude\u00A0'));
			if (group_array[idx] == 0) {
				radio_1.setAttribute('checked', 'checked');
				radio_1.setAttribute('defaultChecked', 'defaultChecked'); // For <= IE 7
			} else if (group_array[idx] == 1) {
				radio_2.setAttribute('checked', 'checked');
				radio_2.setAttribute('defaultChecked', 'defaultChecked'); // For <= IE 7
			} else if (group_array[idx] > 1) {
				radio_3.setAttribute('checked', 'checked');
				radio_3.setAttribute('defaultChecked', 'defaultChecked'); // For <= IE 7
			}
			td_2.appendChild(radio_1);
			td_3.appendChild(radio_2);
			td_4.appendChild(radio_3);
			tr.appendChild(td_1);
			tr.appendChild(td_2);
			tr.appendChild(td_3);
			tr.appendChild(td_4);
		} else {
			var td_1 = document.createElement('td');
			td_1.appendChild(document.createTextNode(name_array[idx]+':'));
			tr.appendChild(td_1);
			for (var td_idx = 0; td_idx < feature_num; td_idx++) {
				var td_x = document.createElement('td');
				var radio_x = document.createElement('input');
				radio_x.setAttribute('type', 'radio');
				radio_x.setAttribute('name', 'datalabel'+(idx+1));
				radio_x.setAttribute('value', td_idx);
				if (group_array[idx] == td_idx) {
					radio_x.setAttribute('checked', 'checked');
					radio_x.setAttribute('defaultChecked', 'defaultChecked'); // For <= IE 7
				}
				td_x.appendChild(document.createTextNode((td_idx+1)+'\u00A0'));
				td_x.appendChild(radio_x);
				tr.appendChild(td_x);
			}
			var td_2 = document.createElement('td');
			var radio_1 = document.createElement('input');
			radio_1.setAttribute('type', 'radio');
			radio_1.setAttribute('name', 'datalabel'+(idx+1));
			radio_1.setAttribute('value', 'exclude');
			if (group_array[idx] > (feature_num-1)) {
				radio_1.setAttribute('checked', 'checked');
				radio_1.setAttribute('defaultChecked', 'defaultChecked'); // For <= IE 7
			}
			td_2.appendChild(document.createTextNode('Exclude\u00A0'));
			td_2.appendChild(radio_1);
			tr.appendChild(td_2);
		}
		table.appendChild(tr);
	}
	var dest = document.getElementById('features');
	dest.appendChild(table);
}
