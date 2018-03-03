// Check form functions
var submit_value;
var total_queues_uploaded = 0;
function submit_1() {
	submit_value = "Submit";
}
function submit_2() {
	submit_value = "Cancel";
}
function checkpost(form) {
	var es = form.elements;
	var l = es.length;
	var msgs = [];
	for (var idx = 0; idx < l; idx++) {
		var e = es[idx];
		msgs.push('name=' + e.name + ', type=' + e.type + ', value=' + e.value);
	}
	alert(msgs.join('\n'));
	return true;
}
function checkform_upload(form) {
	var msgs = [];
	var es = form.elements;
	var l = es.length;
	var data_empty = 0;
	var name_empty = 0;
	for (var idx = 0; idx < l; idx++) {
		var e = es[idx];
		if (/^sampledata/.test(e.name)) {
			if (/^\s*$/.test(e.value)) {
				data_empty++;
			}
		} else if (/^samplename/.test(e.name)) {
			if (/^\s*$/.test(e.value)) {
				name_empty++;
			}
			
		}
	}
	if (!(/^([\w-]+(?:\.[\w-]+)*)@((?:[\w-]+\.)*\w[\w-]{0,66})\.([a-z]{2,6}(?:\.[a-z]{2})?)$/i.test(form.email.value))) {
		msgs.push("Please enter a valid email address.");
	}
	if (index == 0) {
		msgs.push("Please add files to upload.");
	} else if (index == 1) {
		msgs.push("Please upload more than one file.");
	} else {
		if (data_empty > 0) {
			msgs.push("Please select a file for each file added.")
		}
		if (name_empty > 0) {
			if (index != name_empty) {
				msgs.push("If you wish to use sample names, please assign names to all samples.");
			}
		}
	}
	if (msgs.length > 0) {
		alert(msgs.join('\n'));
		return false;
	}
	return true;
}
function checkform_multipleupload(form) {
	var msgs = [];
	if (form === false) {
		return false;
	}
	if (!(/^([\w-]+(?:\.[\w-]+)*)@((?:[\w-]+\.)*\w[\w-]{0,66})\.([a-z]{2,6}(?:\.[a-z]{2})?)$/i.test(form.email.value))) {
		msgs.push('Please enter a valid email address.');
	}
	for (var idx = 0; idx < total; idx++) {
		var uploader = $('#uploader'+idx).pluploadQueue();
		if (uploader.files.length === 0) {
			if (total == 2) {
				if (idx == 0) {
					msgs.push('Group 1 - Control: You must at least upload one file.');
				} else if (idx == 1) {
					msgs.push('Group 2 - Case Study: You must at least upload one file.');
				}
			} else {
				msgs.push('Group '+idx+': You must at least upload one file.');
			}
		}
	}
	if (msgs.length > 0) {
		alert(msgs.join('\n'));
		return false;
	}
	for (var idx = 0; idx < total; idx++) {
		var uploader = $('#uploader'+idx).pluploadQueue();
		// When all files are uploaded submit form
		uploader.bind('UploadComplete', function(uploader) {
			if (uploader.files.length === (uploader.total.uploaded + uploader.total.failed)) {
				total_queues_uploaded++;
				if (total_queues_uploaded === total) {
					form.submit();
				}
			}
		});
		uploader.start();
	}
	document.getElementById('upload_button').setAttribute('disabled', 'disabled');
	document.getElementById('reset_button').setAttribute('disabled', 'disabled');
	return false;
}
function checkform_submit(form) {
	if (submit_value == "Cancel") {
		return true;
	}
	var msgs = [];
	var es = form.elements;
	var l = es.length;
	var feature_num;
	if ((form.test_type.value == "ttest") || (form.test_type.value == "DESeq")) {
		feature_num = 2;
	} else if ((form.test_type.value == "ANOVA") || (form.test_type.value == "ANOVAnegbin")) {
		feature_num = form.ANOVA_features.value;
	}
	var sample_data_total = 0;
	var data_array = new Array(feature_num);
	var exclude_total = 0;
	// Initialize all counts to 0
	for (var idx = 0; idx < feature_num; idx++) {
		data_array[idx] = 0;
	}
	for (var idx = 0; idx < l; idx++) {
		var e = es[idx];
		if (/^datalabel/.test(e.name)) {
			if (e.checked) {
				if (e.value == "exclude") {
					exclude_total++;
				} else {
					data_array[e.value]++;
				}
			}
		} else if (/^filename/.test(e.name)) {
			sample_data_total++;
		}
	}
	if ((exclude_total != sample_data_total) && (exclude_total != (sample_data_total-1))) {
		if ((form.test_type.value == "ttest") || (form.test_type.value == "DESeq")) {
			if (data_array[0] == 0) {
				msgs.push("There are no samples in the control group. Please select one or more samples for the control group.");
			}
			if (data_array[1] == 0) {
				msgs.push("There are no samples in the case group. Please select one or more samples for the case group.");
			}
		} else if ((form.test_type.value == "ANOVA") || (form.test_type.value == "ANOVAnegbin")) {
			for (var idx = 0; idx < feature_num; idx++) {
				if (data_array[idx] == 0) {
					msgs.push("There are no samples in group "+(idx+1)+". Please select one or more samples for group "+(idx+1)+".");
				}
			}
		}
	}
	if (exclude_total == sample_data_total) {
		msgs.push("All samples are excluded; there is no data to process. Please select samples for the other features.");
	}
	if (exclude_total == (sample_data_total-1)) {
		msgs.push("Only one sample is currently selected for use; all other samples are excluded. Please select one or more samples to process.");
	}
	if (form.negative_normalization.value == 4) {
		if ((form.negative_4_pvalue.value <= 0) || (form.negative_4_pvalue.value >= 1)) {
			msgs.push("Negative normalization Student's t-test p-value cutoff must be: 0 < cutoff < 1.");
		}
	}
	if (form.test_type.value == "ttest") {
		if ((form.ttest_pvalue.value <= 0) || (form.ttest_pvalue.value > 1)) {
			msgs.push("T-test p-value cutoff must be: 0 < cutoff <= 1.");
		}
		if (form.ttest_mean.value < 0) {
			msgs.push("T-test mean cutoff must be: cutoff > 0.");
		}
	}
	if (form.test_type.value == "DESeq") {
		if ((form.DESeq_pvalue.value <= 0) || (form.DESeq_pvalue.value > 1)) {
			msgs.push("DESeq p-value cutoff must be: 0 < cutoff <= 1.");
		}
		if (form.DESeq_mean.value < 0) {
			msgs.push("DESeq mean cutoff must be: cutoff > 0.");
		}
	}
	if (form.test_type.value == "ANOVA") {
		if ((form.ANOVA_pvalue.value <= 0) || (form.ANOVA_pvalue.value > 1)) {
			msgs.push("One-way ANOVA p-value cutoff must be: 0 < cutoff <= 1.");
		}
		if (form.ANOVA_mean.value < 0) {
			msgs.push("One-way ANOVA mean cutoff must be: cutoff > 0.");
		}
	}
	if (form.test_type.value == "ANOVAnegbin") {
		if ((form.ANOVA_pvalue.value <= 0) || (form.ANOVA_pvalue.value > 1)) {
			msgs.push("One-way ANOVA (negative binomial) p-value cutoff must be: 0 < cutoff <= 1.");
		}
		if (form.ANOVA_mean.value < 0) {
			msgs.push("One-way ANOVA (negative binomial) mean cutoff must be: cutoff > 0.");
		}
	}
	if (msgs.length > 0) {
		alert(msgs.join('\n'));
		return false;
	}
	return true;
}
