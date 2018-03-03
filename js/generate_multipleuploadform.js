var total = 0;
var group_name_uc = "";
var group_name_lc = "";
//var num_features_has_focus = false;
function add_div(idx) {
	var this_div = document.createElement('div');
	this_div.setAttribute('id', 'uploader'+idx);
	var this_msg = document.createElement('p');
	this_msg.appendChild(document.createTextNode('Your browser doesn\'t have Flash, Silverlight, Gears, BrowserPlus or HTML5 support.'));
	this_div.setAttribute('id', 'uploader'+idx);
	this_div.appendChild(this_msg);
	var master_div = document.getElementById('uploader');
	master_div.appendChild(this_div);
}
//function remove_div(idx) {
//	var master_div = document.getElementById('uploader');
//	master_div.removeChild(document.getElementById('uploader'+idx));
//}
function update_div() {
	var number = document.getElementById('number').value;
	if ((number == 0) || (number == 1)) {
		alert('Please enter 2 or more groups.');
		return false;
	}
	if (number > 10) {
		var answer = confirm ("Are you sure you require "+number+" groups?");
		if (!answer) {
			return false;
		}
	}
	// If greater than current number, add more divs and uploaders
	if (number > total) {
		number = Number(number); // convert string to number
		for (var idx = total; idx < number; idx++) {
			if (number == 2) {
				if (idx == 0) {
					group_name_uc = "Group 1: Control";
					group_name_lc = "the control group";
				} else if (idx == 1) {
					group_name_uc = "Group 2: Case Study";
					group_name_lc = "the case study group";
				}
			} else {
				group_name_uc = "Group "+(idx+1);
				group_name_lc = "group "+(idx+1);
			}
			add_div(idx);
			// Convert divs to queue widgets
			$('#uploader'+idx).pluploadQueue({
				// General settings
				runtimes : 'html5,flash,silverlight,gears,html4',
				url : '/cgi-bin/upload.php',
				max_file_size : '1mb',
				unique_names : false,
				multiple_queues : false,
				// Specify what files to browse for
				filters : [
					{title : "RCC files", extensions : "rcc"}
				],
				// Flash settings
				flash_swf_url : '/js/plupload.flash.swf',
				// Silverlight settings
				silverlight_xap_url : '/js/plupload.silverlight.xap',
				// Extra params
				multipart_params : { jobid : job_id, groupid : idx }
			});
		}
	}
	// Else if less than current number, destroy uploaders and remove divs
	//} else if (number < total) {
	//	for (var idx = number; idx < total; idx++) {
	//		$('#uploader'+idx).pluploadQueue().destroy();
	//		remove_div(idx);
	//	}
	//}
	// Update total
	total = number;
	// Add hidden field for job id
	var master_div = document.getElementById('uploader');
	var this_hidden_job = document.createElement('input');
	this_hidden_job.setAttribute('name', 'job_id');
	this_hidden_job.setAttribute('type', 'hidden');
	this_hidden_job.setAttribute('value', job_id);
	master_div.appendChild(this_hidden_job);
	// Add hidden field for number of features
	var this_hidden_num = document.createElement('input');
	this_hidden_num.setAttribute('name', 'num_feat');
	this_hidden_num.setAttribute('type', 'hidden');
	this_hidden_num.setAttribute('value', number);
	master_div.appendChild(this_hidden_num);
	// Add <br/> before buttons
	master_div.appendChild(document.createElement('br'));
	// Add submit button
	var this_submit = document.createElement('input');
	this_submit.setAttribute('type', 'submit');
	this_submit.setAttribute('id', 'upload_button');
	this_submit.setAttribute('value', 'Submit');
	master_div.appendChild(this_submit);
	// Add &nbsp;&nbsp; before next button
	master_div.appendChild(document.createTextNode('\u00A0\u00A0'));
	// Add reload button
	var this_button = document.createElement('input');
	this_button.setAttribute('type', 'button');
	this_button.setAttribute('id', 'reset_button');
	this_button.setAttribute('value', 'Reset');
	this_button.setAttribute('onClick', 'window.location.reload();');
	master_div.appendChild(this_button);
	// Hide feature input
	$('.num-features').hide();
}
// Initialize all divs for total
$(document).ready(function() {
	for (var idx = 0; idx < total; idx++) {
		add_div(idx);
	}
	$('#number').keypress(function(key){
		if(key.which != 8 && key.which != 0 && (key.which < 48 || key.which > 57)) {
			if(key.which == 13) {
			//if((key.which == 13) && (num_features_has_focus)) {
				update_div();
				checkform_multipleupload(false);
				//num_features_has_focus = false;
				return false;
			}
			$("#invalidnumber").html("Enter numbers only!").show().fadeOut("slow");
			return false;
		}
	});
	//$("#number").focus(function(){
	//	num_features_has_focus = true;
	//});
});
