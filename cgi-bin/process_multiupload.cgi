#!/usr/bin/perl
##
# process_upload.pl
# 
# Process the files uploaded, stores them in a temporary directory, and
# presents a page to submit a job, presenting all available options available
# to adjust for that job.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 03/12/2011
##

# Add local libraries
BEGIN {
	push (@INC, "./lib");
}

use strict;
use warnings;

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 
use Set::Scalar;
use NanoString::RCC; # local module

my $cgi = new CGI;
print $cgi->header('text/html');

# Limit max upload size per file to 1 MB
$cgi::POST_MAX = 1024 * 1000;

# Define paths for files
my $tmp_path = "../tmp/";

sub printOptionsPage {
	my $email = shift;
	my $filename_ref = shift;
	my @filename = @{$filename_ref};
	my $sample_name_ref = shift;
	my @sample_name = @{$sample_name_ref};
	my $default_label_ref = shift;
	my @default_label = @{$default_label_ref};
	my $group_ref = shift;
	my @group = @{$group_ref};
	my $num_feat = shift;
	my $warnings_ref = shift;
	my @warnings = @{$warnings_ref};
	my $job_id = shift;
	print <<ENDHTML1;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1"/>
<meta name="description" content="description"/>
<meta name="keywords" content="keywords"/> 
<meta name="author" content="author"/> 
<link rel="stylesheet" type="text/css" href="/css/default.css" media="screen"/>
<title>NanoStriDE - NanoString Differential Expression</title>
</head>
<script type="text/javascript">
ENDHTML1
	print ("var all_filename = new Array(\"".join ("\",\"", @filename)."\");\n");
	if (scalar (@sample_name) > 0) {
		print ("var all_sample_name = new Array(\"".join ("\",\"", @sample_name)."\");\n");
	} else {
		print ("var all_sample_name = false;\n");
	}
	print ("var all_default_label = new Array(\"".join ("\",\"", @default_label)."\");\n");
	print ("var all_group = new Array(".join (",", @group).");\n");
	print ("var num_feat = ".$num_feat.";\n");
	print ("</script>\n");
	print ("<script type=\"text/javascript\" src=\"/js/process_job.js\"></script>\n");
	print <<ENDHTML2;
<body>
<div class="container">

	<noscript>

	<div class="holder_top"></div>

	<div class="holder">
		<h1>This Site Requires JavaScript</h1>
		<p>
			Please enable JavaScript for this site.
			<a target="_new" href="http://www.google.com/search?q=How+do+I+enable+JavaScript&amp;btnI=1">
			Please click here for information</a> on how to do this.<br/>
			Once JavaScript is enabled <a href="javascript:window.location.reload()">click here to reload</a> this site.
		</p>
	</div>

	<div class="holder_bottom"></div>

	</noscript>

	<div class="title">
		<h1 id="title">NanoStriDE</h1>
		<h3>NanoString Differential Expression</h3>
	</div>

	<div class="navigation">
		<a href="/about.html">About</a>
		<a href="/license.html">License</a>
		<a href="/faq.html">FAQ</a>
		<a href="/">Upload Data</a>
		<div class="clearer"><span></span></div>
	</div>

	<div class="holder_top"></div>

	<div class="holder">
ENDHTML2
	# Print out warnings
	my $t2 = "\t\t";
	if (scalar (@warnings) > 0) {
		print ("$t2<p class=\"warning\">");
	}
	foreach my $message (@warnings) {
		print ("$t2".$message."<br/>");
	}
	if (scalar (@warnings) > 0) {
		print ("$t2</p>");
	}
	print <<ENDHTML3;
		<form name="process_job" action="/cgi-bin/process_job.cgi" enctype="multipart/form-data"
			method="post" onsubmit="return checkform_submit(this);">
			<h2>Conditions&nbsp;<img title="Select which samples belong to which conditions. Exclude removes a sample from the data set to be processed." src="/img/question.png" />&nbsp;:</h2>
			<div id="features"></div><br/>
ENDHTML3
	if (scalar (@sample_name) > 0) {
		print ("<h3><label>Label type&nbsp;<img title=\"Select what you would like to use to represent the samples as in the analysis. Choices are: an automatically generated default from the date, stage position, FOV count, and lane number, or the sample names from the data set itself, or the filenames of the uploaded files.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"label_type\" class=\"labeltype\" id=\"labeltype\"><option value=\"default\">Automatically Generated Default</option><option value=\"samplename\" selected=\"selected\">Sample Names from Files</option><option value=\"filename\">Filename</option></select></h3>");
	} else {
		print ("<h3><label>Label type&nbsp;<img title=\"Select what you would like to use to represent the samples as in the analysis. Choices are: an automatically generated default from the date, stage position, FOV count, and lane number or the filenames of the uploaded files.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"label_type\" class=\"labeltype\" id=\"labeltype\"><option value=\"default\" selected=\"selected\">Automatically Generated Default</option><option value=\"filename\">Filename</option></select></h3>");
	}
	print <<ENDHTML4;
			</br>
			<h2>Options:</h2>
			<h3><label>Data type&nbsp;<img title="Select what type of data type the samples are. Choices are: mRNA or microRNA." src="/img/question.png" />&nbsp;:&nbsp<select name="data_type" class="datatype" id="datatype"><option value="miRNA" selected="selected">miRNA</option><option value="mRNA">mRNA</option></select></h3>
ENDHTML4
			#~ <h3 class="datatype-mirna"><label class="datatype-mirna">Sample type correction&nbsp;<img class="datatype-mirna" title="When using microRNA, corrections have to be made to the counts depending on which probe set is used. Choices are: human or mouse." src="/img/question.png" />&nbsp;:&nbsp<select name="sample_type" class="datatype-mirna"><option value="mouse" selected="selected">mouse</option><option value="human">human</option></select></h3>
#~ ENDHTML4
	my $t3 = "\t\t\t";
	if (scalar (@filename) >= 3) {
		if ($num_feat >= 3) {
			print ("$t3<h3><label>Test type&nbsp;<img title=\"Select the type of statistical test to be used. If assuming a normal distribution, use t-test for two conditions and one way ANOVA for more than two conditions. If assuming a negative binomial distribution (which is more appropriate for NanoString data), use DESeq for two conditions and one way ANOVA (negative binomial) that uses DESeq's ANODEV for more than two conditions.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\">DESeq (negative binomial)</option><option value=\"ANOVA\">One-way ANOVA</option><option value=\"ANOVAnegbin\" selected=\"selected\">One-way ANOVA (negative binomial)</option></select></h3>\n");
		} else {
			print ("$t3<h3><label>Test type&nbsp;<img title=\"Select the type of statistical test to be used. If assuming a normal distribution, use t-test for two conditions and one way ANOVA for more than two conditions. If assuming a negative binomial distribution (which is more appropriate for NanoString data), use DESeq for two conditions and one way ANOVA (negative binomial) that uses DESeq's ANODEV for more than two conditions.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\" selected=\"selected\">DESeq (negative binomial)</option><option value=\"ANOVA\">One-way ANOVA</option><option value=\"ANOVAnegbin\">One-way ANOVA (negative binomial)</option></select></h3>\n");
		}
	} else {
		print ("$t3<h3><label>Test type&nbsp;<img title=\"Select the type of statistical test to be used. If assuming a normal distribution, use t-test for two conditions. If assuming a negative binomial distribution (which is more appropriate for NanoString data), use DESeq for two conditions.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\" selected=\"selected\">DESeq (negative binomial)</option></select></h3>\n");
	}
	print <<ENDHTML5;
			<h3 class="testtype-scn"><label class="testtype-scn">Sample content normalization&nbsp;<img title="Select the type of normalization across the entire data set for t-test or one way ANOVA. Normalizing to housekeeping genes is appropriate when mRNA samples are provided and normalizing to the entire sample is appropriate when microRNA samples are provided. The normalize to the highest miRNAs option normalizes to the top 75 microRNAs in the first sample." src="/img/question.png" />&nbsp;:&nbsp<select id="scnselect" name="sample_content_normalization" class="testtype-scn"><option value="1">Normalize to housekeeping mRNA</option><option value="2" selected="selected">Normalize to entire miRNA sample</option><option value="3">Normalize to highest miRNAs</option></select></h3>
ENDHTML5
	my $file_number = scalar (@filename);
	if ($file_number >= 3) {
		if ($num_feat <= 3) {
			print ("$t3<h3 class=\"testtype-ANOVA-features-label\"><label class=\"testtype-ANOVA-features-label\" id=\"testtypeANOVA\">Number of conditions&nbsp;<img class=\"testtype-ANOVA-features-label\" title=\"Select the number of conditions to be used for ANOVA.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"ANOVA_features\" class=\"testtype-ANOVA-features\" id=\"ANOVAfeatures\"><option value=\"3\" selected=\"selected\">3</option>");
		} else {
			print ("$t3<h3 class=\"testtype-ANOVA-features-label\"><label class=\"testtype-ANOVA-features-label\" id=\"testtypeANOVA\">Number of conditions&nbsp;<img class=\"testtype-ANOVA-features-label\" title=\"Select the number of conditions to be used for ANOVA.\" src=\"/img/question.png\" />&nbsp;:&nbsp<select name=\"ANOVA_features\" class=\"testtype-ANOVA-features\" id=\"ANOVAfeatures\"><option value=\"3\">3</option>");
		}
		if ($file_number >= 4) {
			for my $i (4..$file_number) {
				if ($num_feat == $i) {
					print ("<option value=\"".$i."\" selected=\"selected\">".$i."</option>");
				} else {
					print ("<option value=\"".$i."\">".$i."</option>");
				}
			}
		}
		print ("</select></h3>\n");
	}
	print <<ENDHTML6;
			</br>
			<h2>Advanced Options:</h2>
			<h3 class="negnorm-label"><label class="negnorm-label">Negative correction&nbsp;<img class="negnorm-label" title="Select the type of negative correction to be used in t-test or one way ANOVA. Options for this subtractive correction are: the mean, the mean with 2 standard deviations, the maximum value of the negative controls, and using a one tailed Student's t-test. For the one tailed Student's t-test, the subtractive correction is applied if a probe is statistically significant by means of a p-value cutoff, otherwise the values of that probe are set to zero." src="/img/question.png" />&nbsp;:&nbsp<select class="negnorm" name="negative_normalization" class="negnorm" id="negativenormalization"><option value="1">Mean</option><option value="2" selected="selected">Mean + 2 * standard deviation</option><option value="3">Maximum value of negative controls</option><option value="4">One tailed Student's t-test</option></select></h3>
			<h3 class="negnorm-4"><label class="negnorm-4">Negative correction Student's t-test p-value cutoff&nbsp;<img class="negnorm-4" title="Select the p-value cutoff for the one tailed Student's t-test negative correction. Default: 0.05" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="negative_4_pvalue" value="0.05" class="negnorm-4"/></h3>
			<h3 class="testtype-ttest"><label class="testtype-ttest">T-test p-value cutoff&nbsp;<img class="testtype-ttest" title="Select the p-value cutoff for the t-test. Default: 0.05" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ttest_pvalue" value="0.05" class="testtype-ttest"/></h3>
			<h3 class="testtype-ttest"><label class="testtype-ttest">T-test mean cutoff&nbsp;<img class="testtype-ttest" title="Select the mean count cutoff for the t-test. Default: 0" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ttest_mean" value="0" class="testtype-ttest"/></h3>
			<h3 class="testtype-DESeq"><label class="testtype-DESeq">DESeq p-value cutoff&nbsp;<img class="testtype-DESeq" title="Select the p-value cutoff for DESeq. Default: 0.05" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="DESeq_pvalue" value="0.05" class="testtype-DESeq"/></h3>
			<h3 class="testtype-DESeq"><label class="testtype-DESeq">DESeq mean cutoff&nbsp;<img class="testtype-DESeq" title="Select the mean count cutoff for DESeq. Default: 0" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="DESeq_mean" value="0" class="testtype-DESeq"/></h3>
			<h3 class="testtype-ANOVA"><label class="testtype-ANOVA">ANOVA p-value cutoff&nbsp;<img class="testtype-ANOVA" title="Select the p-value cutoff for one way ANOVA. Default: 0.05" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ANOVA_pvalue" value="0.05" class="testtype-ANOVA"/></h3>
			<h3 class="testtype-ANOVA"><label class="testtype-ANOVA">ANOVA mean cutoff&nbsp;<img class="testtype-ANOVA" title="Select the mean count cutoff for one way ANOVA. Default: 0" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ANOVA_mean" value="0" class="testtype-ANOVA"/></h3>
			<h3 class="testtype-ANOVAnegbin"><label class="testtype-ANOVAnegbin">ANOVA (negative binomial) p-value cutoff&nbsp;<img class="testtype-ANOVAnegbin" title="Select the p-value cutoff for one way ANOVA (negative binomial) using DESeq's ANODEV. Default: 0.05" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ANOVAnegbin_pvalue" value="0.05" class="testtype-ANOVAnegbin"/></h3>
			<h3 class="testtype-ANOVAnegbin"><label class="testtype-ANOVAnegbin">ANOVA (negative binomial) mean cutoff&nbsp;<img class="testtype-ANOVAnegbin" title="Select the mean count cutoff for one way ANOVA (negative binomial) using DESeq's ANODEV. Default: 0" src="/img/question.png" />&nbsp;:&nbsp<input type="text" name="ANOVAnegbin_mean" value="0" class="testtype-ANOVAnegbin"/></h3>
			<h3><label>p-value for heatmap&nbsp;<img title="Select the type of p-value to be used for the statistical analysis for generating the heatmap. Choices are: unadjusted p-value or adjusted p-value. Default: adjusted p-value" src="/img/question.png" />&nbsp;:&nbsp<select name="adjpvalue"><option value="false">p-value (no adjustment)</option><option value="true" selected="selected">adjusted p-value</option></select></h3>
			<h3><label>Adjusted p-value type&nbsp;<img title="Select the type of correction to be used for the adjusted p-values. Default: Benjamini & Hochberg (FDR)" src="/img/question.png" />&nbsp;:&nbsp<select name="adjpvalue_type"><option value="bonferroni">Bonferroni</option><option value="holm">Holm</option><option value="hochberg">Hochberg</option><option value="hommel">Hommel</option><option value="BH" selected="selected">Benjamini & Hochberg</option><option value="BY">Benjamini & Yekutieli</option></select></h3>
			<h3><label>Cluster samples in heatmap&nbsp;<img title="Select if the samples should be clustered using hierarchical clustering with Euclidean distance in the heatmap." src="/img/question.png" />&nbsp;:&nbsp<select name="heatmap_clustercols"><option value="yes" selected="selected">Yes</option><option value="no">No</option></select></h3>
			<h3><label>Display key in heatmap&nbsp;<img title="Select whether the key/legend should be displayed for the log scaled values in the heatmap." src="/img/question.png" />&nbsp;:&nbsp<select name="heatmap_key"><option value="yes" selected="selected">Yes</option><option value="no">No</option></select></h3>
			<h3><label>Heatmap colors&nbsp;<img title="Select the color scheme to be used when generating the heatmap. Choices are displayed in low-neutral-high color format." src="/img/question.png" />&nbsp;:&nbsp<select name="heatmap_colors"><option value="1" selected="selected">green-black-red</option><option value="2">green-white-red</option><option value="3">blue-black-yellow</option><option value="4">blue-white-yellow</option></select></h3>
			<h3><label>Output format&nbsp;<img title="Select the format of output for the results. Choices are: tab-delimited files (tab) or comma separated values (csv)." src="/img/question.png" />&nbsp;:&nbsp<select name="output_type"><option value="csv" selected="selected">csv</option><option value="tab_delim">tab-delimited</option></select></h3>
ENDHTML6
	# Print email in hidden field
	print ("$t3<input type=\"hidden\" name=\"email\" value=\"".$email."\"/>\n");
	# Print sample data order in hidden fields
	for my $i (0..$#filename) {
		print ("$t3<input type=\"hidden\" name=\"filename".$i."\" value=\"".$filename[$i]."\"/>\n");
	}
	# Print sample names in hidden fields if valid
	for my $i (0..$#sample_name) {
		print ("$t3<input type=\"hidden\" name=\"samplename".$i."\" value=\"".$sample_name[$i]."\"/>\n");
	}
	# Print default labels in hidden fields
	for my $i (0..$#default_label) {
		print ("$t3<input type=\"hidden\" name=\"defaultlabel".$i."\" value=\"".$default_label[$i]."\"/>\n");
	}
	# Add sample labels later by javascript
	# Print job id in hidden field
	print("$t3<input type=\"hidden\" name=\"job_id\" value=\"".$job_id."\"/\n>");
	print <<ENDHTML7;
			</br>
			<input type="submit" name="action" value="Submit" onclick="submit_1();"/>&nbsp;&nbsp;
			<input type="submit" name="action" value="Cancel" onclick="submit_2();"/>
		</form>
	</div>

	<div class="holder_bottom"></div>

	<div class="holder_top"></div>

	<div class="holder">

		<div class="footer">&copy; 2011 <a href="mailto:admin\@nanostride.soe.ucsc.edu">Chris Brumbaugh</a>. Valid <a href="http://jigsaw.w3.org/css-validator/check/referer">CSS</a> &amp; <a href="http://validator.w3.org/check?uri=referer">XHTML</a>. Template design by <a href="http://arcsin.se">Arcsin</a>
		</div>

	</div>

	<div class="holder_bottom"></div>

</div>
</body>
</html>
ENDHTML7
}

# After POST, retrieve passed form parameters
my @all_form_names = $cgi->param;
my $email = '';
my $job_id = '';
my $num_feat = 0;
# Need to figure out why form array params do not work...
# Instead name each name+index for now & grab all params
foreach my $form_name (@all_form_names) {
	if ($form_name eq "email") {
		$email = $cgi->param ($form_name); # get e-mail address
	} elsif ($form_name eq "job_id") {
		$job_id = $cgi->param ($form_name); # get job id
	} elsif ($form_name eq "num_feat") {
		$num_feat = $cgi->param ($form_name); # get number of groups
	}
}

# Set current temp path for job
my $current_tmp_path = $tmp_path.$job_id.'/';

# Read in groups and filenames
my %group_to_filename = ();
my @filenames = ();
open (groupRead, $current_tmp_path.$job_id.'_groups.tab');
my $line = '';
while ($line = <groupRead>) {
	$line =~ s/\r|\n//g;
	my @info = split ('\t', $line);
	my $group = $info[0];
	my $filename = $info[1];
	push (@filenames, $filename);
	if (defined $group_to_filename{$group}) {
		push (@{$group_to_filename{$group}}, $filename);
	} else {
		@{$group_to_filename{$group}} = ($filename);
	}
}
close (groupRead);
unlink ($current_tmp_path.$job_id.'_groups.tab');

#~ my @lines = ();
#~ while (my ($k, $v) = each %group_to_filename) {
	#~ push (@lines, "key: $k, value: (".join (", ", @{$v}).")");
#~ }
#~ die (join ("; ", @lines));

# Read in file information for uploaded files, process warnings
my %filename_to_sample_names = ();
my %filename_to_default_labels = ();
my @warnings = ();
for my $i (0..$#filenames) {
	my $path = $current_tmp_path.$filenames[$i];
	my $filename = $filenames[$i];
	my $RCC = NanoString::RCC->new ($path);
	# Get sample name
	$filename_to_sample_names{$filename} = $RCC->getValue ("Sample Attributes", "ID");
	# Create default label
	my $raw_data_date = $RCC->getValue ("Sample Attributes", "Date");
	my $raw_data_stageposition = $RCC->getValue ("Lane Attributes", "StagePosition");
	my $raw_data_fovcount = $RCC->getValue ("Lane Attributes", "FovCount");
	my $raw_data_laneid = $RCC->getValue ("Lane Attributes", "ID");
	$filename_to_default_labels{$filename} = "d".$raw_data_date."_sp".$raw_data_stageposition."_fc".$raw_data_fovcount."_li".$raw_data_laneid;
	# Check for warnings
	# 1. FOVCounted to FOVCount ratio; flag if less than 80%
	my $fovCount_fovCounted_ratio = (($RCC->getValue ("Lane_Attributes", "FovCounted")) / ($RCC->getValue ("Lane_Attributes", "FovCount")));
	if ($fovCount_fovCounted_ratio < 0.8) {
		push (@warnings, "WARNING: ".$filename." has FOVCount/FOVCounted < 80% (".($fovCount_fovCounted_ratio*100)."%).");
	}
	# 2. Binding density - should be between 0.05 and 2.25; flag if not
	my $binding_density = $RCC->getValue ("Lane_Attributes", "BindingDensity");
	if ($binding_density < 0.05) {
		push (@warnings, "WARNING: ".$filename." has binding density < 0.05 (".$binding_density.").");
	} elsif ($binding_density > 2.25) {
		push (@warnings, "WARNING: ".$filename." has binding density > 2.25 (".$binding_density.").");
	}
	# Do other warnings at time of normalization, append to warnings.txt written from R
	# 3. Positive control normalization - factor should be between 0.3 and 3; flag if not
	# 4. 0.5fM control counts should be above average of negative controls in 90% of lanes
	# 5. Linear correlation of positive controls vs concentration should have R^2 greater than 0.95 in at least 90% of lanes
}

# Sort by groups and put into arrays (filename, sample name, default label, group)
@filenames = ();
my @sample_names = ();
my @default_labels = ();
my @groups = ();
foreach my $group (sort keys %group_to_filename) {
	my @filenames_for_group = sort (@{$group_to_filename{$group}});
	foreach my $this_filename (@filenames_for_group) {
		push (@filenames, $this_filename);
		push (@sample_names, $filename_to_sample_names{$this_filename});
		push (@default_labels, $filename_to_default_labels{$this_filename});
		push (@groups, $group);
	}
}

#~ # Check for valid sample name usage, destroy sample names if not valid
my $sample_name_set = new Set::Scalar (@sample_names);
if ($sample_name_set->size != scalar (@sample_names)) {
	@sample_names = ();
}
foreach my $this_sample_name (@sample_names) {
	if ($this_sample_name =~ m/^[\s]+$/) {
		@sample_names = ();
		last;
	}
}

# Print out new page with options to submit
printOptionsPage ($email, \@filenames, \@sample_names, \@default_labels, \@groups, $num_feat, \@warnings, $job_id);

exit(0);
