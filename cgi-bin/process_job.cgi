#!/usr/bin/perl
##
# process_job.pl
# 
# Process the files stored in a temporary directory and executes the job
# depending if the user submitted the job. If the user cancels the job, the
# temporary files uploaded to the server are removed. If the job was submitted,
# the script first creates an entry in the job queue, then creates a results
# page that automatically refreshes and finally calls the script to process the
# job queue.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 03/15/2011
##

# Add local libraries
BEGIN {
	push (@INC, "./lib");
}

use strict;
use warnings;

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 
use Unix::PID;
use File::Copy;
use Proc::Daemon;

my $cgi = new CGI;
my $base_url = 'http://localhost';
$| = 1; # turn on autoflush to output cgi without waiting for subprocess

# Define paths for files
my $tmp_path = "../tmp/";
my $work_path = "../result/";
my $absolute_work_path = "/var/www/result/";
#~ my $queue_file = $work_path."queue.txt";
my $log_path = "../result/";
my $R_log_path = "/tmp/Statistics-R/";

sub printRefreshPage {
	my $refresh_page = shift;
	my $job_id = shift;
	my $refresh_rate = 30;
	print WRITEFILE <<ENDHTML1;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1"/>
<meta name="description" content="description"/>
<meta name="keywords" content="keywords"/> 
<meta name="author" content="author"/> 
ENDHTML1
	print WRITEFILE ("<meta http-equiv=\"Refresh\" content=\"".$refresh_rate."; url=".$refresh_page."\"/>\n");
	print WRITEFILE <<ENDHTML2;
<link rel="stylesheet" type="text/css" href="/css/default.css" media="screen"/>
<title>NanoStriDE - NanoString Differential Expression</title>
</head>
<body>
<div class="container">

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
	my $t2 = "\t\t";
	print WRITEFILE ("$t2<p>Job ID ".$job_id." is being processed... This page automatically refreshes every ".$refresh_rate." seconds.</p>");
	print WRITEFILE <<ENDHTML3;
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
ENDHTML3
}

# After POST, retrieve passed form parameters
my @all_form_names = $cgi->param;
my $job_id = '';
my $email = '';
my $data_type = '';
my $sample_type = '';
my $test_type = '';
my $ANOVA_features = '';
my $sample_content_normalization = '';
my $negative_normalization = '';
my $negative_4_pvalue = '';
my $ttest_pvalue = '';
my $ttest_mean = '';
my $DESeq_pvalue = '';
my $DESeq_mean = '';
my $ANOVA_pvalue = '';
my $ANOVA_mean = '';
my $ANOVAnegbin_pvalue = '';
my $ANOVAnegbin_mean = '';
my $adjpvalue = '';
my $adjpvalue_type = '';
my $output_type = '';
my $heatmap_clustercols = '';
my $heatmap_key = '';
my $heatmap_colors = '';
my $action = '';
my $label_type = '';
my @data = ();
my @data_label = ();
my @sample_name = ();
my @default_label = ();
my @name = ();
foreach my $form_name (@all_form_names) {
	if ($form_name eq "job_id") {
		$job_id = $cgi->param ($form_name);
	} elsif ($form_name eq "email") {
		$email = $cgi->param ($form_name);
	} elsif ($form_name eq "data_type") {
		$data_type = $cgi->param ($form_name);
	} elsif ($form_name eq "sample_type") {
		$sample_type = $cgi->param ($form_name);
	} elsif ($form_name eq "test_type") {
		$test_type = $cgi->param ($form_name);
	} elsif ($form_name eq "ANOVA_features") {
		$ANOVA_features = $cgi->param ($form_name);
	} elsif ($form_name eq "sample_content_normalization") {
		$sample_content_normalization = $cgi->param ($form_name);
	} elsif ($form_name eq "negative_normalization") {
		$negative_normalization = $cgi->param ($form_name);
	} elsif ($form_name eq "negative_4_pvalue") {
		$negative_4_pvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "ttest_pvalue") {
		$ttest_pvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "ttest_mean") {
		$ttest_mean = $cgi->param ($form_name);
	} elsif ($form_name eq "DESeq_pvalue") {
		$DESeq_pvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "DESeq_mean") {
		$DESeq_mean = $cgi->param ($form_name);
	} elsif ($form_name eq "ANOVA_pvalue") {
		$ANOVA_pvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "ANOVA_mean") {
		$ANOVA_mean = $cgi->param ($form_name);
	} elsif ($form_name eq "ANOVAnegbin_pvalue") {
		$ANOVAnegbin_pvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "ANOVAnegbin_mean") {
		$ANOVAnegbin_mean = $cgi->param ($form_name);
	} elsif ($form_name eq "output_type") {
		$output_type = $cgi->param ($form_name);
	} elsif ($form_name eq "adjpvalue") {
		$adjpvalue = $cgi->param ($form_name);
	} elsif ($form_name eq "adjpvalue_type") {
		$adjpvalue_type = $cgi->param ($form_name);
	} elsif ($form_name eq "heatmap_clustercols") {
		$heatmap_clustercols = $cgi->param ($form_name);
	} elsif ($form_name eq "heatmap_key") {
		$heatmap_key = $cgi->param ($form_name);
	} elsif ($form_name eq "heatmap_colors") {
		$heatmap_colors = $cgi->param ($form_name);
	} elsif ($form_name eq "label_type") {
		$label_type = $cgi->param ($form_name);
	} elsif ($form_name =~ m/^filename\d+$/) {
		push (@data, $cgi->param ($form_name)); # get file names
	} elsif ($form_name =~ m/^datalabel\d+$/) {
		push (@data_label, $cgi->param ($form_name)); # get features
	} elsif ($form_name =~ m/^samplename\d+$/) {
		push (@sample_name, $cgi->param ($form_name)); # get sample names
	} elsif ($form_name =~ m/^defaultlabel\d+$/) {
		push (@default_label, $cgi->param ($form_name)); # get sample names
	} elsif ($form_name eq 'action') {
		$action = $cgi->param ($form_name);
	}
}

# Set labels
if ($label_type eq "default") {
	@name = @default_label;
} elsif ($label_type eq "samplename") {
	@name = @sample_name;
} elsif ($label_type eq "filename") {
	@name = @data;
}

# If canceled, delete the temporary files and redirect to index.html
if ($action eq 'Cancel') {
	# Wipe the temporary directory
	my $tmpdir = $tmp_path.$job_id."/";
	my @tmpfiles = glob ($tmpdir."*");
	unlink (@tmpfiles);
	rmdir ($tmpdir);
	# Redirect to index.html
	my $append_url = '/';
	print $cgi->redirect($base_url.$append_url);
	exit (0);
}

# Not cancelled/was submitted, so move the files to the working directory
umask (0000);
my $tmpdir = $tmp_path.$job_id."/";
my $workdir = $work_path.$job_id."/";
move ($tmpdir, $workdir);

# Clean working dir of any previous jobs
my @delete_files = glob ($workdir."*.csv");
push (@delete_files, glob ($workdir."*.tab"));
push (@delete_files, glob ($workdir."*.txt"));
push (@delete_files, glob ($workdir."*.html"));
push (@delete_files, glob ($workdir."*.png"));
push (@delete_files, glob ($workdir."*.zip"));
unlink (@delete_files);

# Create customized readme file to inform user
my $readme_file = $work_path.$job_id."/README.txt";
open (WRITEFILE, ">:utf8", $readme_file);
print WRITEFILE "The output of the file consists of the following files:\n";
print WRITEFILE "00a_-_options.txt: The options that were selected to run the current NanoStriDE job.\n";
print WRITEFILE "00b_-_warnings.txt: Any warnings that are reported to the user. These may consist of warnings regarding issues with the actual NanoString run itself (e.g. problems with binding density, etc.) or report an issue with the differential analysis itself (e.g. the heatmap could not be generated due to an insufficient number of statistically significant genes/probes).\n";
#~ if ($data_type eq "miRNA") {
	#~ print WRITEFILE "00c_-_corrected_data.csv/.tab: The human or mouse microRNA probe corrections applied to the raw data for the NanoString platform.\n";
#~ } elsif ($data_type eq "mRNA") {
	#~ print WRITEFILE "00c_-_raw_data.csv/.tab: The raw data for the NanoString platform.\n";
	#~ if (($test_type eq 'ttest') || ($test_type eq 'ANOVA')) {
		#~ print WRITEFILE "00d_-_housekeeping.csv/.tab: The housekeeping gene data for the NanoString platform.\n";
	#~ }
#~ }
print WRITEFILE "00c_-_raw_data.csv/.tab: The raw data for the NanoString platform.\n";
if (($test_type eq 'ttest') || ($test_type eq 'ANOVA')) {
	print WRITEFILE "00d_-_housekeeping.csv/.tab: The housekeeping gene data for the NanoString platform.\n";
}
if (($test_type eq 'ttest') || ($test_type eq 'ANOVA')) {
	print WRITEFILE "01_-_positive_corrected.csv/.tab: The positive corrected data with a multiplicative normalization for the spike-in control sequences with known abundances per NanoString guidelines.\n";
	print WRITEFILE "02_-_negative_corrected.csv/.tab: The negative corrected data with a subtractive normalization for negative control probes known not to be present in the probe set per NanoString guidelines.\n";
	print WRITEFILE "03_-_sample_content_normalized.csv/.tab: The sample content normalized data with a multiplicative normalization to ensure that transcript qualntity levels are comparable across samples per NanoString guidelines.\n";
	if ($test_type eq 'ttest') {
		print WRITEFILE "04_-_sorted_ttest.csv/.tab: The results of the t-test performed on the sample content normalized data. The columns from left to right are: id (the gene/probe id), baseMean (the mean of a given gene/probe), baseMeanA (the base mean of a given gene/probe for the control group), baseMeanB (the base mean of a given gene/probe for the case group), foldChange (the fold change), log2FoldChange (the log base 2 fold change), p.value (the unadjusted p-value), p.value.adj (the adjusted p-value), statistic (the t-statistic), dm (the difference of the group means).\n";
	} elsif ($test_type eq 'ANOVA') {
		print WRITEFILE "04_-_sorted_ANOVA.csv/.tab: The results of the one way ANOVA performed on the sample content normalized data. The columns from left to right are: id (the gene/probe id), baseMean (the mean of a given gene/probe), baseMean# (the base mean of a given gene/probe for the numbered group), sum.of.squares (the sum of squares), mean.square (the mean square), f.value (the F-test statistic), p.value (the unadjusted p-value), p.value.adj (the adjusted p-value).\n";
	}
	print WRITEFILE "05a_-_heatmap.csv/.tab: The normalized data for the statistically significant genes (less than the p-value cutoff and greater than the base mean cutoff) that are used in the heatmap.\n";
	print WRITEFILE "05b_-_heatmap.png: The heatmap for the statistically significant genes.\n";
} elsif (($test_type eq 'DESeq') || ($test_type eq 'ANOVAnegbin')) {
	if ($test_type eq 'DESeq') {
		print WRITEFILE "01_-_DESeq_normalized.csv/.tab: The data normalized by DESeq using default size factors. Refer to 'Anders S. and Huber W., Differential expression analysis for sequence count data. Genome Biology, 2010' for further details.\n";
		print WRITEFILE "02_-_sorted_DESeq.csv/.tab: The results of DESeq performed on the DESeq normalized data. The columns from left to right are: baseMean (the mean of a given gene/probe), baseMeanA (the base mean of a given gene/probe for the control group), baseMeanB (the base mean of a given gene/probe for the case group), foldChange (the fold change), log2FoldChange (the log base 2 fold change), pval (the unadjusted p-value), padj (the adjusted p-value).\n";
	} elsif ($test_type eq 'ANOVAnegbin') {
		print WRITEFILE "01_-_DESeq_ANODEV_normalized.csv/.tab: The data normalized by DESeq using default size factors. Refer to 'Anders S. and Huber W., Differential expression analysis for sequence count data. Genome Biology, 2010' for further details.\n";
		print WRITEFILE "02_-_sorted_DESeq_ANODEV.csv/.tab: The results of the one way ANOVA performed on the DESeq normalized data. The columns from left to right are: id (the gene/probe id), baseMean (the mean of a given gene/probe), baseMean# (the base mean of a given gene/probe for the numbered group), p.value (the unadjusted p-value), p.value.adj (the adjusted p-value).\n";
	}
	print WRITEFILE "03a_-_heatmap.csv/.tab: The normalized data for the statistically significant genes (less than the p-value cutoff and greater than the base mean cutoff) that are used in the heatmap.\n";
	print WRITEFILE "03b_-_heatmap.png: The heatmap for the statistically significant genes.\n";
}
close (WRITEFILE);
chmod (0666, $readme_file);

# Create options file to store parameters for user
# Write options in user readable format
my $options_file = $work_path.$job_id."/options.txt";
open (WRITEFILE, ">:utf8", $options_file);
print WRITEFILE "File names: ".join (', ', @data)."\n";
if ($#data == $#name) {
	print WRITEFILE "Sample names: ".join (', ', @name)."\n";
}
if (($test_type eq "ttest") or ($test_type eq "DESeq")) {
	my @control_index = ();
	my @case_index = ();
	my @exclude_index = ();
	for my $i (0..$#data_label) {
		if ($data_label[$i] eq "exclude") {
			push (@exclude_index, $i);
		} elsif ($data_label[$i] == 0) {
			push (@control_index, $i);
		} elsif ($data_label[$i] == 1) {
			push (@case_index, $i);
		}
	}
	my @control = ();
	my @case = ();
	my @exclude = ();
	foreach my $index (@control_index) {
		if ($#data == $#name) {
			push (@control, $name[$index]);
		} else {
			push (@control, $data[$index]);
		}
	}
	foreach my $index (@case_index) {
		if ($#data == $#name) {
			push (@case, $name[$index]);
		} else {
			push (@case, $data[$index]);
		}
	}
	foreach my $index (@exclude_index) {
		if ($#data == $#name) {
			push (@exclude, $name[$index]);
		} else {
			push (@exclude, $data[$index]);
		}
	}
	print WRITEFILE "Control group: ".join (', ', @control)."\n";
	print WRITEFILE "Case group: ".join (', ', @case)."\n";
	print WRITEFILE "Excluded samples: ".join (', ', @exclude)."\n";
}
if (($test_type eq "ANOVA") or ($test_type eq "ANOVAnegbin")) {
	my %all_index = ();
	my @exclude_index = ();
	for my $i (0..($ANOVA_features-1)) {
		$all_index{$i} = ();
	}
	for my $i (0..$#data_label) {
		if ($data_label[$i] eq "exclude") {
			push (@exclude_index, $i);
		} else {
			push(@{$all_index{$data_label[$i]}} ,$i);
		}
	}
	my %all_groups = ();
	my @exclude = ();
	for my $i (0..($ANOVA_features-1)) {
		$all_groups{$i} = ();
	}
	while (my ($key, $value) = each (%all_index)) {
		if ($#data == $#name) {
			foreach my $index (@{$value}) {
				push (@{$all_groups{$key}}, $name[$index]);
			}
		} else {
			foreach my $index (@{$value}) {
				push (@{$all_groups{$key}}, $data[$index]);
			}
		}
	}
	foreach my $index (@exclude_index) {
		if ($#data == $#name) {
			push (@exclude, $name[$index]);
		} else {
			push (@exclude, $data[$index]);
		}
	}
	foreach my $key (sort keys %all_groups) {
		my $value = $all_groups{$key};
		print WRITEFILE "Group ".($key+1).": ".join (', ', @{$value})."\n";
	}
	print WRITEFILE "Excluded samples: ".join (', ', @exclude)."\n";
}
print WRITEFILE "Data type: ".$data_type."\n";
#~ if ($data_type eq "miRNA") {
	#~ print WRITEFILE "Sample type correction: ".$sample_type."\n";
#~ }
my $negative_print = '';
if ($negative_normalization == 1) {
	$negative_print = "Mean";
} elsif ($negative_normalization == 2) {
	$negative_print = "Mean + 2 * standard deviation";
} elsif ($negative_normalization == 3) {
	$negative_print = "Maximum value of negative controls";
} elsif ($negative_normalization == 4) {
	$negative_print = "One tailed Student's t-test";
}
if (($test_type eq 'ttest') || ($test_type eq 'ANOVA')) {
	print WRITEFILE "Negative correction: ".$negative_print."\n";
	if ($negative_normalization == 4) {
		print WRITEFILE "Negative correction Student's t-test p-value cutoff: ".$negative_4_pvalue."\n";
	}
}
if ($test_type eq 'ttest') {
	print WRITEFILE "Test type: t-test\n";
	print WRITEFILE "T-test p-value cutoff: ".$ttest_pvalue."\n";
	print WRITEFILE "T-test mean cutoff: ".$ttest_mean."\n";
	my $sample_content_print = '';
	if ($sample_content_normalization == 1) {
		$sample_content_print = "Normalize to housekeeping mRNA";
	} elsif ($sample_content_normalization == 2) {
		$sample_content_print = "Normalize to entire miRNA sample";
	} elsif ($sample_content_normalization == 3) {
		$sample_content_print = "Normalize to highest miRNAs";
	}
	print WRITEFILE "Sample content normalization: ".$sample_content_print."\n";
}
if ($test_type eq 'DESeq') {
	print WRITEFILE "Test type: DESeq (negative binomial test)\n";
	print WRITEFILE "DESeq p-value cutoff: ".$DESeq_pvalue."\n";
	print WRITEFILE "DESeq mean cutoff: ".$DESeq_mean."\n";
}
if ($test_type eq 'ANOVA') {
	print WRITEFILE "Test type: One way ANOVA\n";
	print WRITEFILE "ANOVA p-value cutoff: ".$ANOVA_pvalue."\n";
	print WRITEFILE "ANOVA mean cutoff: ".$ANOVA_mean."\n";
}
if ($test_type eq 'ANOVAnegbin') {
	print WRITEFILE "Test type: One way ANOVA (negative binomial)\n";
	print WRITEFILE "ANOVA (negative binomial) p-value cutoff: ".$ANOVAnegbin_pvalue."\n";
	print WRITEFILE "ANOVA (negative binomial) mean cutoff: ".$ANOVAnegbin_mean."\n";
}
if ($adjpvalue eq "true") {
	print WRITEFILE "p-value used: adjusted p-value\n";
} elsif ($adjpvalue eq "false") {
	print WRITEFILE "p-value used: p-value (no adjustment)\n";
}
if ($adjpvalue_type eq "bonferroni") {
	print WRITEFILE "Adjusted p-value type: Bonferroni adjusted p-value\n";
} elsif ($adjpvalue_type eq "holm") {
	print WRITEFILE "Adjusted p-value type: Holm adjusted p-value\n";
} elsif ($adjpvalue_type eq "hochberg") {
	print WRITEFILE "Adjusted p-value type: Hochberg adjusted p-value\n";
} elsif ($adjpvalue_type eq "hommel") {
	print WRITEFILE "Adjusted p-value type: Hommel adjusted p-value\n";
} elsif ($adjpvalue_type eq "BH") {
	print WRITEFILE "Adjusted p-value type: Benjamini & Hochberg adjusted p-value\n";
} elsif ($adjpvalue_type eq "BY") {
	print WRITEFILE "Adjusted p-value type: Benjamini & Yekutieli adjusted p-value\n";
}
close (WRITEFILE);
chmod (0666, $options_file);

# Exclude selected files from @files, @name, @data_label
my @exclude_index = ();
for my $i (0..$#data_label) {
	if ($data_label[$i] eq "exclude") {
		push (@exclude_index, $i);
	}
}
my @new_data = ();
my @new_name = ();
my @new_data_label = ();
for my $i (0..$#data) {
	if (! (grep {$_ eq $i} @exclude_index)) {
		push (@new_data, $data[$i]);
		if ($name[$i] !~ m/^\s*$/) {
			push (@new_name, $name[$i]);
		}
		push (@new_data_label, $data_label[$i]);
	}
}
@data = @new_data;
@name = @new_name;
@data_label = @new_data_label;
undef @new_data;
undef @new_name;
undef @new_data_label;

# Create job entry (parameters to heatmap script)
my $current_job = '';
my @flags = ();
my @files = ();
foreach my $file (@data) {
	push (@files, $work_path.$job_id."/".$file);
}
push (@flags, '--inputfile=\''.join (',', @files).'\'');
if ($#data == $#name) {
	push (@flags, '--labels=\''.join (',', @name).'\'');
}
push (@flags, '--conditions=\''.join (',', @data_label).'\'');
push (@flags, '--datatype=\''.$data_type.'\'');
if ($data_type eq 'miRNA') {
	push (@flags, '--correctiontype=\''.$sample_type.'\'');
}
if (($test_type eq 'ttest') or ($test_type eq 'ANOVA')) {
	push (@flags, '--normalizecontent');
}
push (@flags, '--negative='.$negative_normalization);
push (@flags, '--neg4ttestpval='.$negative_4_pvalue);
push (@flags, '--samplecontent='.$sample_content_normalization);
push (@flags, '--outputdir=\''.$absolute_work_path.$job_id.'/\'');
push (@flags, '--testtype=\''.$test_type.'\'');
if ($test_type eq 'ttest') {
	push (@flags, '--pvaluecutoff='.$ttest_pvalue);
	push (@flags, '--meancutoff='.$ttest_mean);
} elsif ($test_type eq 'DESeq') {
	push (@flags, '--pvaluecutoff='.$DESeq_pvalue);
	push (@flags, '--meancutoff='.$DESeq_mean);
} elsif ($test_type eq 'ANOVA') {
	push (@flags, '--pvaluecutoff='.$ANOVA_pvalue);
	push (@flags, '--meancutoff='.$ANOVA_mean);
} elsif ($test_type eq 'ANOVAnegbin') {
	push (@flags, '--pvaluecutoff='.$ANOVAnegbin_pvalue);
	push (@flags, '--meancutoff='.$ANOVAnegbin_mean);
}
if ($adjpvalue eq "true") {
	push (@flags, '--adjpvalue');
}
if ($adjpvalue_type ne "") {
	push (@flags, '--adjpvaluetype=\''.$adjpvalue_type.'\'');
}
my $heatmapcolors = '';
if ($heatmap_colors == 1) {
	$heatmapcolors = 'colorRampPalette(c(\"green\", \"black\", \"red\"))(100)';
} elsif ($heatmap_colors == 2) {
	$heatmapcolors = 'colorRampPalette(c(\"green\", \"white\", \"red\"))(100)';
} elsif ($heatmap_colors == 3) {
	$heatmapcolors = 'colorRampPalette(c(\"blue\", \"black\", \"yellow\"))(100)';
} elsif ($heatmap_colors == 4) {
	$heatmapcolors = 'colorRampPalette(c(\"blue\", \"white\", \"yellow\"))(100)';
}
push (@flags, '--heatmapcolors=\''.$heatmapcolors.'\'');
if ($heatmap_clustercols eq 'no') {
	push (@flags, '--heatmapclustercols=\'cluster_cols = FALSE\'');
}
if ($heatmap_key eq 'yes') {
	push (@flags, '--heatmapkey=\'legend = TRUE\'');
}
if ($output_type eq 'tab_delim') {
	push (@flags, '--taboutput');
}
push (@flags, '--warnings=1');
push (@flags, '--debug=1');
$current_job = join (' ', @flags);

#~ # Append job to job queue file
#~ open (WRITEFILE, ">>:utf8", $queue_file);
#~ print WRITEFILE ($job_id."\n");
#~ print WRITEFILE ($email."\n");
#~ print WRITEFILE (join (',', @files)."\n");
#~ print WRITEFILE ($current_job."\n");
#~ close (WRITEFILE);
#~ # chmod (0644, $queue_file);
#~ chmod (0666, $queue_file);

# Create auto-refreshing results page in working directory
my $refresh_file = $work_path.$job_id."/index.html";
my $refresh_page = $base_url."/result/".$job_id.'/';
open (WRITEFILE, ">:utf8", $refresh_file);
printRefreshPage ($refresh_page, $job_id);
close (WRITEFILE);
#~ chmod (0644, $refresh_file);
chmod (0666, $refresh_file);

# Redirect to results page
my $append_url = '/result/'.$job_id.'/';
print $cgi->redirect ($base_url.$append_url);

# Check for and kill any previous processes (if user hit back before complete and resubmitted)
if (-e $log_path.$job_id.'.pid') {
	my $pid = new Unix::PID ();
	$pid->kill_pid_file ($log_path.$job_id.'_execute.pid'); # kill script
	$pid->kill_pid_file_no_unlink($R_log_path.$job_id.'/R.pid'); # kill R
}

# Create daemon process for execute_job.pl
my $daemon = Proc::Daemon->new (
	work_dir		=> './',
	child_STDERR	=> '+>>'.$log_path.$job_id.'.log',
	pid_file		=> $log_path.$job_id.'_execute.pid',
	exec_command	=> './execute_job.pl --jobid="'.$job_id.'" --email="'.$email.'" --files="'.join (',', @files).'" --currentjob="'.$current_job.'" --anovafeatures="'.$ANOVA_features.'" --adjpvalue="'.$adjpvalue.'" --adjpvaluetype="'.$adjpvalue_type.'"',
);
$daemon->Init ();

#~ my $pid = Unix::PID->new ();
#~ $pid->wait_for_pidsof (
	#~ {
		#~ 'pid_list'	=> ($daemon->get_pid ()),
		#~ 'sleep_for'	=> 15, # in seconds
		#~ 'max_loops'	=> 20, # if not done, might be stuck
		#~ 'hit_max_loops' => sub {
			#~ $daemon->Kill_Daemon ();
		#~ },
	#~ }
#~ );

#~ # Create daemon process for process_job_queue.pl
#~ my $daemon = Proc::Daemon->new(
	#~ work_dir		=> './',
	#~ child_STDERR	=> '+>>'.$log_path.'process_job_queue.log',
	#~ exec_command	=> './process_job_queue.pl',
#~ );

#~ # Check if process_job_queue.pl is running
#~ # If not, start an instance of it
#~ my @work_files = glob ($work_path."*");
#~ my $found_pid_file = 0;
#~ foreach my $file (@work_files) {
	#~ if ($file =~ m/^process_job_queue\.pid$/) {
		#~ $found_pid_file = 1;
		#~ my $pid = new Unix::PID();
		#~ my $isnotrunning = $pid->pid_file_no_unlink($file);
		#~ if ($isnotrunning) {
			#~ $daemon->Init ();
		#~ }
	#~ }
#~ }
#~ if (!$found_pid_file) {
	#~ $daemon->Init ();
#~ }

exit (0);
