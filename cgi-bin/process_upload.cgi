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
use NanoString::RCC; # local module

my $cgi = new CGI;
print $cgi->header('text/html');

# Limit max upload size per file to 1 MB
$cgi::POST_MAX = 1024 * 1000;

# Define paths for files
my $tmp_path = "../tmp/";

sub printOptionsPage {
	my $email = shift;
	my $data_ref = shift;
	my @data = @{$data_ref};
	my $name_ref = shift;
	my @name = @{$name_ref};
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
<link rel="stylesheet" type="text/css" href="//css/default.css" media="screen"/>
<title>Normalize NanoString Raw Data</title>
</head>
<script type="text/javascript">
ENDHTML1
	if ($#data == $#name) {
		print ("var all_names = new Array(\"".join ("\",\"", @name)."\");\n</script>\n");
	} else {
		print ("var all_names = new Array(\"".join ("\",\"", @data)."\");\n</script>\n");
	}
	print ("<script type=\"text/javascript\" src=\"/js/process_job.js\"></script>\n");
	print <<ENDHTML2;
</script>
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
		<h1 id="title">NanoString</h1>
		<h2>Normalize Data and Get Heatmaps</h2>
	</div>

	<div class="navigation">
		<a href="/contact.html">Contact Us</a>
		<a href="/about.html">About</a>
		<a href="/faq.html">FAQ</a>
		<a href="/">Upload Data</a>
		<div class="clearer"><span></span></div>
	</div>

	<div class="holder_top"></div>

	<div class="holder">
ENDHTML2
	# Print out warnings
	my $t2 = "\t\t";
	if (scalar(@warnings) > 0) {
		print ("$t2<p class=\"warning\">");
	}
	foreach my $message (@warnings) {
		print ("$t2".$message."<br/>");
	}
	if (scalar(@warnings) > 0) {
		print ("$t2</p>");
	}
	print <<ENDHTML3;
		<form name="process_job" action="/cgi-bin/process_job.cgi" enctype="multipart/form-data"
			method="post" onsubmit="return checkform_submit(this);">
			<h2>Feature Selection:</h2>
			<div id="features"></div><br/>
			<h2>Options:</h2>
			<h3><label>Data type:&nbsp<select name="data_type" class="datatype" id="datatype"><option value="miRNA" selected="selected">miRNA</option><option value="mRNA">mRNA</option></select></h3>
			<h3 class="datatype-mirna"><label class="datatype-mirna">Sample type correction:&nbsp<select name="sample_type" class="datatype-mirna"><option value="mouse" selected="selected">mouse</option><option value="human">human</option></select></h3>
ENDHTML3
	my $t3 = "\t\t\t";
	if (scalar(@data) >= 3) {
		print ("$t3<h3><label>Test type:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\" selected=\"selected\">DESeq (negative binomial)</option><option value=\"ANOVA\">One-way ANOVA</option><option value=\"ANOVAnegbin\">One-way ANOVA (negative binomial)</option></select></h3>\n");
		#~ print ("$t3<h3><label>Test type:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\" selected=\"selected\">DESeq (negative binomial)</option><option value=\"ANOVA\">One-way ANOVA</option></select></h3>\n");
	} else {
		print ("$t3<h3><label>Test type:&nbsp<select name=\"test_type\" class=\"testtype\" id=\"testtype\"><option value=\"ttest\">t-test</option><option value=\"DESeq\" selected=\"selected\">DESeq (negative binomial)</option></select></h3>\n");
	}
	print <<ENDHTML4;
			<h3 class="testtype-scn"><label class="testtype-scn">Sample content normalization:&nbsp<select name="sample_content_normalization" class="testtype-scn"><option value="1">Normalize to housekeeping mRNA</option><option value="2" selected="selected">Normalize to entire miRNA sample</option><option value="3">Normalize to highest miRNAs</option></select></h3>
ENDHTML4
	my $feature_number = scalar(@data);
	if ($feature_number >= 3) {
		print ("$t3<h3 class=\"testtype-ANOVA-features-label\"><label class=\"testtype-ANOVA-features-label\" id=\"testtypeANOVA\">Number of features:&nbsp<select name=\"ANOVA_features\" class=\"testtype-ANOVA-features\" id=\"ANOVAfeatures\"><option value=\"3\" selected=\"selected\">3</option>");
		if ($feature_number >= 4) {
			for my $i (4..$feature_number) {
				print ("<option value=\"".$i."\">".$i."</option>");
			}
		}
		print ("</select></h3>\n");
	}
	print <<ENDHTML5;
			</br>
			<h2>Advanced Options:</h2>
			<h3><label>Negative normalization:&nbsp<select name="negative_normalization" class="negnorm" id="negativenormalization"><option value="1">Mean</option><option value="2" selected="selected">Mean + 2 * standard deviation</option><option value="3">Maximum value of negative controls</option><option value="4">One tailed Student's t-test</option></select></h3>
			<h3 class="negnorm-4"><label class="negnorm-4">Negative normalization Student's t-test p-value cutoff:&nbsp<input type="text" name="negative_4_pvalue" value="0.05" class="negnorm-4"/></h3>
			<h3 class="testtype-ttest"><label class="testtype-ttest">T-test p-value cutoff:&nbsp<input type="text" name="ttest_pvalue" value="0.05" class="testtype-ttest"/></h3>
			<h3 class="testtype-ttest"><label class="testtype-ttest">T-test mean cutoff:&nbsp<input type="text" name="ttest_mean" value="0" class="testtype-ttest"/></h3>
			<h3 class="testtype-DESeq"><label class="testtype-DESeq">DESeq p-value cutoff:&nbsp<input type="text" name="DESeq_pvalue" value="0.05" class="testtype-DESeq"/></h3>
			<h3 class="testtype-DESeq"><label class="testtype-DESeq">DESeq mean cutoff:&nbsp<input type="text" name="DESeq_mean" value="0" class="testtype-DESeq"/></h3>
			<h3 class="testtype-ANOVA"><label class="testtype-ANOVA">ANOVA p-value cutoff:&nbsp<input type="text" name="ANOVA_pvalue" value="0.05" class="testtype-ANOVA"/></h3>
			<h3 class="testtype-ANOVA"><label class="testtype-ANOVA">ANOVA mean cutoff:&nbsp<input type="text" name="ANOVA_mean" value="0" class="testtype-ANOVA"/></h3>
			<h3 class="testtype-ANOVAnegbin"><label class="testtype-ANOVAnegbin">ANOVA (negative binomial) p-value cutoff:&nbsp<input type="text" name="ANOVAnegbin_pvalue" value="0.05" class="testtype-ANOVAnegbin"/></h3>
			<h3 class="testtype-ANOVAnegbin"><label class="testtype-ANOVAnegbin">ANOVA (negative binomial) mean cutoff:&nbsp<input type="text" name="ANOVAnegbin_mean" value="0" class="testtype-ANOVAnegbin"/></h3>
			<h3><label>p-value for heatmap:&nbsp<select name="adjpvalue"><option value="false" selected="selected">p-value (no adjustment)</option><option value="true">adjusted p-value</option></select></h3>
			<h3><label>Adjusted p-value type:&nbsp<select name="adjpvalue_type"><option value="bonferroni">Bonferroni</option><option value="holm">Holm</option><option value="hochberg">Hochberg</option><option value="hommel">Hommel</option><option value="BH" selected="selected">Benjamini & Hochberg</option><option value="BY">Benjamini & Yekutieli</option></select></h3>
			<h3><label>Cluster samples in heatmap:&nbsp<select name="heatmap_clustercols"><option value="yes" selected="selected">Yes</option><option value="no">No</option></select></h3>
			<h3><label>Display key in heatmap:&nbsp<select name="heatmap_key"><option value="yes" selected="selected">Yes</option><option value="no">No</option></select></h3>
			<h3><label>Heatmap colors:&nbsp<select name="heatmap_colors"><option value="1" selected="selected">green-black-red</option><option value="2">green-white-red</option><option value="3">blue-black-yellow</option><option value="4">blue-white-yellow</option></select></h3>
			<h3><label>Output format:&nbsp<select name="output_type"><option value="csv" selected="selected">csv</option><option value="tab_delim">tab-delimited</option></select></h3>
ENDHTML5
	# Print email in hidden field
	print ("$t3<input type=\"hidden\" name=\"email\" value=\"".$email."\"/>\n");
	# Print sample data order in hidden fields
	for my $i (0..$#data) {
		print ("$t3<input type=\"hidden\" name=\"sampledata".$i."\" value=\"".$data[$i]."\"/>\n");
	}
	# Print sample name order in hidden fields
	for my $i (0..$#name) {
		print ("$t3<input type=\"hidden\" name=\"samplename".$i."\" value=\"".$name[$i]."\"/>\n");
	}
	# Print job id in hidden field
	print("$t3<input type=\"hidden\" name=\"job_id\" value=\"".$job_id."\"/\n>");
	print <<ENDHTML6;
			</br>
			<input type="submit" name="action" value="Submit" onclick="submit_1();"/>
			<input type="submit" name="action" value="Cancel" onclick="submit_2();"/>
		</form>
	</div>

	<div class="holder_bottom"></div>

	<div class="holder_top"></div>

	<div class="holder">

		<div class="footer">&copy; 2011 <a href="mailto:nanostring\@achilles.soe.ucsc.edu">Chris Brumbaugh</a>. Valid <a href="http://jigsaw.w3.org/css-validator/check/referer">CSS</a> &amp; <a href="http://validator.w3.org/check?uri=referer">XHTML</a>. Template design by <a href="http://arcsin.se">Arcsin</a>
		</div>

	</div>

	<div class="holder_bottom"></div>

</div>
</body>
</html>
ENDHTML6
}

# After POST, retrieve passed form parameters
my @all_form_names = $cgi->param;
my $email = '';
my @data = ();
my @data_filehandle = ();
my @name = ();
# Need to figure out why form array params do not work...
# Instead name each name+index for now & grab all params
foreach my $form_name (@all_form_names) {
	if ($form_name eq "email") {
		$email = $cgi->param ($form_name); # get e-mail address
	} elsif ($form_name =~ m/^sampledata\d+$/) {
		push (@data, $cgi->param ($form_name)); # get file names
		push (@data_filehandle, $cgi->upload ($form_name)); # get filehandle
	} elsif ($form_name =~ m/^samplename\d+$/) {
		if ($cgi->param ($form_name) !~ m/^\s*$/) {
			push (@name, $cgi->param ($form_name)); # get sample names
		}
	}
}

# Generate random tmp ID:
umask (0000);
my @time_data = localtime(time);
$time_data[5] += 1900;
my $join_time = join ('-', @time_data);
my $job_id = $join_time."_".int(rand(4096));
# Final job id = time joined by hyphens + random number
#~ mkdir ($tmp_path.$job_id, 0755);
mkdir ($tmp_path.$job_id, 0777);
# Store tmp store path
my $current_tmp_path = $tmp_path.$job_id."/";

# Validate file names in raw data submitted
for my $i (0..$#data) {
	$data[$i] =~ s/\s/_/g; # replace whitespace with underscores
	$data[$i] =~ s/[^a-zA-Z0-9_.-]//g; # filter for safe characters for filenames
}

# Place files in tmp directory
for my $i (0..$#data) {
	open (UPLOADFILE, ">$current_tmp_path".$data[$i])
		or die "$!";
	binmode UPLOADFILE;
	my $buffer;
	my $io_handle = $data_filehandle[$i]->handle;
	while ($io_handle->read ($buffer, 1024)) {
		print UPLOADFILE $buffer;
	}
	close UPLOADFILE;
	#~ chmod (0644, $current_tmp_path.$data[$i]);
	chmod (0666, $current_tmp_path.$data[$i]);
}

# Read in file information for uploaded files, process warnings
my @warnings = ();
my @tmp_files = glob ($current_tmp_path."*.RCC");
push (@tmp_files, glob ($current_tmp_path."*.rcc"));
for my $i (0..$#tmp_files) {
	my $path = $tmp_files[$i];
	my $RCC = NanoString::RCC->new ($path);
	# Check for warnings
	# 1. FOVCounted to FOVCount ratio; flag if less than 80%
	my $fovCount_fovCounted_ratio = (($RCC->getValue ("Lane_Attributes", "FovCounted")) / ($RCC->getValue ("Lane_Attributes", "FovCount")));
	if ($fovCount_fovCounted_ratio < 0.8) {
		push (@warnings, "WARNING: ".$data[$i]." has FOVCount/FOVCounted < 80%.");
	}
	# 2. Binding density - should be between 0.05 and 2.25; flag if not
	my $binding_density = $RCC->getValue ("Lane_Attributes", "BindingDensity");
	if ($binding_density < 0.05) {
		push (@warnings, "WARNING: ".$data[$i]." has binding density < 0.05.");
	} elsif ($binding_density > 2.25) {
		push (@warnings, "WARNING: ".$data[$i]." has binding density > 2.25.");
	}
	# Do other warnings at time of normalization, append to warnings.txt written from R
	# 3. Positive control normalization - factor should be between 0.3 and 3; flag if not
	# 4. 0.5fM control counts should be above average of negative controls in 90% of lanes
	# 5. Linear correlation of positive controls vs concentration should have R^2 greater than 0.95 in at least 90% of lanes
}

# Print out new page with options to submit
printOptionsPage ($email, \@data, \@name, \@warnings, $job_id);

exit(0);
