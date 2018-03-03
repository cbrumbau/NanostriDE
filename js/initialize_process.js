// Hide or show elements depending on input values
// Handle feature selection generation
$(document).ready(function() {
	var datatype = document.getElementById('datatype');
	if (datatype.value != "miRNA") {
		$('.datatype-mirna').hide();
	} else {
		$('.datatype-mirna').show();
	}
	var testtype = document.getElementById('testtype');
	var labeltype = document.getElementById('labeltype');
	if (testtype.value == "ttest") {
		$('.testtype-DESeq').hide();
		$('.testtype-ANOVA').hide();
		$('.testtype-ANOVAnegbin').hide();
		$('.testtype-ANOVA-features-label').hide();
		$('.testtype-ANOVA-features').hide();
		$('.testtype-ttest').show();
		$('.negnorm-label').show();
		$('.negnorm').show();
		$('.testtype-scn').show();
		set_features(2, labeltype.value, all_group);
	} else if (testtype.value == "DESeq") {
		$('.testtype-ttest').hide();
		$('.testtype-ANOVA').hide();
		$('.testtype-ANOVAnegbin').hide();
		$('.testtype-ANOVA-features-label').hide();
		$('.testtype-ANOVA-features').hide();
		$('.negnorm-label').hide();
		$('.negnorm').hide();
		$('.testtype-scn').hide();
		$('.testtype-DESeq').show();
		set_features(2, labeltype.value, all_group);
	} else if (testtype.value == "ANOVA") {
		$('.testtype-ttest').hide();
		$('.testtype-DESeq').hide();
		$('.testtype-ANOVAnegbin').hide();
		ANOVA_features = document.getElementById('ANOVAfeatures');
		if (all_filename.length > 3) {
			$('.testtype-ANOVA').show();
			$('.testtype-ANOVA-features-label').show();
			$('.testtype-ANOVA-features').show();
		}
		$('.negnorm-label').show();
		$('.negnorm').show();
		$('.testtype-scn').show();
		set_features(ANOVA_features.value, labeltype.value, all_group);
	} else if (testtype.value == "ANOVAnegbin") {
		$('.testtype-ttest').hide();
		$('.testtype-DESeq').hide();
		$('.testtype-ANOVA').hide();
		$('.negnorm-label').hide();
		$('.negnorm').hide();
		$('.testtype-scn').hide();
		ANOVA_features = document.getElementById('ANOVAfeatures');
		if (all_filename.length > 3) {
			$('.testtype-ANOVAnegbin').show();
			$('.testtype-ANOVA-features-label').show();
			$('.testtype-ANOVA-features').show();
		}
		set_features(ANOVA_features.value, labeltype.value, all_group);
	}
	var negnorm = document.getElementById('negativenormalization');
	if (negnorm.value != "4") {
		$('.negnorm-4').hide();
	} else if ((negnorm.value == "4") && ((testtype.value == "ttest") || (testtype.value == "ANOVA"))) {
		$('.negnorm-4').show();
	}
	$(".labeltype").change(function(){
		var val = $(this).val();
		if (testtype.value == "ttest") {
			set_features(2, labeltype.value, all_group);
		} else if (testtype.value == "DESeq") {
			set_features(2, labeltype.value, all_group);
		} else if (testtype.value == "ANOVA") {
			set_features(ANOVA_features.value, labeltype.value, all_group);
		} else if (testtype.value == "ANOVAnegbin") {
			set_features(ANOVA_features.value, labeltype.value, all_group);
		}
	});
	$(".datatype").change(function(){
		var val = $(this).val();
		var scn = document.getElementById('scnselect');
		if (val != "miRNA") {
			$('.datatype-mirna').hide();
			scn.selectedIndex = 0;
		} else {
			$('.datatype-mirna').show();
			scn.selectedIndex = 1;
		}
	});
	$(".testtype").change(function(){
		var val = $(this).val();
		if (val == "ttest") {
			$('.testtype-DESeq').hide();
			$('.testtype-ANOVA').hide();
			$('.testtype-ANOVAnegbin').hide();
			$('.testtype-ANOVA-features-label').hide();
			$('.testtype-ANOVA-features').hide();
			$('.testtype-ttest').show();
			$('.negnorm-label').show();
			$('.negnorm').show();
			var negnorm = document.getElementById('negativenormalization');
			if (negnorm.value == "4") {
				$('.negnorm-4').show();
			}
			$('.testtype-scn').show();
			set_features(2, labeltype.value, all_group);
		} else if (val == "DESeq") {
			$('.testtype-ttest').hide();
			$('.testtype-ANOVA').hide();
			$('.testtype-ANOVAnegbin').hide();
			$('.testtype-ANOVA-features-label').hide();
			$('.testtype-ANOVA-features').hide();
			$('.negnorm-label').hide();
			$('.negnorm').hide();
			var negnorm = document.getElementById('negativenormalization');
			if (negnorm.value == "4") {
				$('.negnorm-4').hide();
			}
			$('.testtype-scn').hide();
			$('.testtype-DESeq').show();
			set_features(2, labeltype.value, all_group);
		} else if (val == "ANOVA") {
			$('.testtype-ttest').hide();
			$('.testtype-DESeq').hide();
			$('.testtype-ANOVAnegbin').hide();
			ANOVA_features = document.getElementById('ANOVAfeatures');
			if (all_filename.length > 3) {
				$('.testtype-ANOVA').show();
				$('.testtype-ANOVA-features-label').show();
				$('.testtype-ANOVA-features').show();
			}
			$('.negnorm-label').show();
			$('.negnorm').show();
			var negnorm = document.getElementById('negativenormalization');
			if (negnorm.value == "4") {
				$('.negnorm-4').show();
			}
			$('.testtype-scn').show();
			set_features(ANOVA_features.value, labeltype.value, all_group);
		} else if (val == "ANOVAnegbin") {
			$('.testtype-ttest').hide();
			$('.testtype-DESeq').hide();
			$('.testtype-ANOVA').hide();
			$('.negnorm-label').hide();
			$('.negnorm').hide();
			var negnorm = document.getElementById('negativenormalization');
			if (negnorm.value == "4") {
				$('.negnorm-4').hide();
			}
			$('.testtype-scn').hide();
			ANOVA_features = document.getElementById('ANOVAfeatures');
			if (all_filename.length > 3) {
				$('.testtype-ANOVAnegbin').show();
				$('.testtype-ANOVA-features-label').show();
				$('.testtype-ANOVA-features').show();
			}
			set_features(ANOVA_features.value, labeltype.value, all_group);
		}
	});
	$(".testtype-ANOVA-features").change(function(){
		var val = $(this).val();
		set_features(val, labeltype.value, all_group);
	});
	$(".negnorm").change(function(){
		var val = $(this).val();
		if (val != "4") {
			$('.negnorm-4').hide();
		} else if (val == "4") {
			$('.negnorm-4').show();
		}
	});
});
