#!/usr/bin/perl
##
# execute_job.pl
# 
# Process the job queue on the web server by processing the job passed to the
# script.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 02/09/2011
##

BEGIN {
	push (@INC, "./lib");
}

use warnings;
use strict;
use FileHandle;
use Getopt::Long;
use Proc::Daemon;
use Unix::PID;
use Archive::Zip;
use MIME::Lite;

my $base_url = 'http://localhost';

# Define paths for files
my $work_path = "../result/";
my $queue_file = "../result/queue.txt";
my $log_path = "../result/";
# Example:
#~ my $Rpackages_dir = "/user_home_path/R/architecture/R_version";
#~ my $Rpackages_dir = "/home/cbrumbau/R/i686-pc-linux-gnu-library/2.11";
my $Rpackages_dir = "/home/cbrumbau/R/i686-pc-linux-gnu-library/2.14";

my $job_id = "";
my $email = "";
my $files = "";
my $flags = "";
my $ANOVA_features = 0;
my $adjpvalue = "";
my $adjpvalue_type = "";
my $args = GetOptions ("jobid=s"			=> \$job_id,
						"email=s"			=> \$email,
						"files=s"			=> \$files,
						"currentjob=s"		=> \$flags,
						"anovafeatures=i"	=> \$ANOVA_features,
						"adjpvalue=s"		=> \$adjpvalue,
						"adjpvaluetype=s"	=> \$adjpvalue_type);

# format_localtime ()
# Provides the local time formatted to be used in debug logs
# Input: None
# Return: A string containing the formatted local time
sub format_localtime {
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekdays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	(my $second, my $minute, my $hour, my $day_of_month, my $month, my $year_offset, my $day_of_week, my $day_of_year, my $daylight_savings) = localtime();
	my $year = 1900 + $year_offset;
	my $the_time = "$weekdays[$day_of_week] $months[$month] $day_of_month, $year, $hour:$minute:$second";
	return "[".$the_time."] ";
}

sub printResultsPage {
	my $workdir = shift;
	my $job_id = shift;
	my $warnings_ref = shift;
	my @warnings = @{$warnings_ref};
	my $test = shift;
	my $pvalue_header = shift;
	my $make_table = shift;
	my $table_ref = shift;
	my %table = %{$table_ref};
	my $keys_ref = shift;
	my @keys = @{$keys_ref};
	print WRITEFILE <<ENDHTML1;
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
<script type="text/javascript" src="/js/execute_job.js">
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
ENDHTML1
	# Print out warnings
	my $t2 = "\t\t";
	if (scalar(@warnings) > 0) {
		print WRITEFILE ("$t2<p class=\"warning\">\n");
	}
	foreach my $message (@warnings) {
		print WRITEFILE ("$t2".$message."<br/>\n");
	}
	if (scalar(@warnings) > 0) {
		print WRITEFILE ("$t2</p>\n\n");
	}
	# Display download link to the zipped results
	my $zip_url = $base_url."/result/".$job_id."/".$job_id.".zip";
	print WRITEFILE ("$t2<h2>Results:</h2><br/>\n$t2<p><a href=\"".$zip_url."\"><img src=\"/img/download-icon.gif\" /></a>&nbsp;&nbsp;<a href=\"".$zip_url."\">Download the normalized data and the results of the job</a></p>\n");
	# Display heatmap
	my @jobfiles = glob ($workdir."*");
	my $heatmap = 0;
	foreach my $file (@jobfiles) {
		if ($file =~ m/heatmap\.png$/) {
			$heatmap = 1;
		}
	}
	my $img_url = "";
	if (($test eq "ttest") || ($test eq "ANOVA")) {
		$img_url = $base_url."/result/".$job_id."/05b_-_heatmap.png";
	} elsif (($test eq "DESeq") || ($test eq "ANOVAnegbin")) {
		$img_url = $base_url."/result/".$job_id."/03b_-_heatmap.png";
	}
	if ($heatmap) {
		print WRITEFILE ("$t2<h2>Heatmap:</h2>\n(Click to enlarge)<br/>\n");
		print WRITEFILE ("$t2<a href=\"".$img_url."\" rel=\"lightbox\"><img src=\"".$img_url."\" height=\"300\" width =\"300\"/></a>\n<br/>\n");
	} else {
		print WRITEFILE ("$t2<h2>Heatmap:</h2>\n$t2<p>Problems were encountered and the heatmap could not be generated. This could be due to the fact that no statistically significant probes were found. Please refer to any warnings and check your choice of options and your data.</p>\n$t2<br/>\n");
	}
	# Display table
	if ($make_table) {
		if (scalar(@{$table{"Gene"}}) > 0) {
			if (($test eq "ttest") || ($test eq "DESeq")) {
				print WRITEFILE ("$t2<h2>p-values and Fold Change:</h2><br/>\n");
			} elsif (($test eq "ANOVA") || ($test eq "ANOVAnegbin")) {
				print WRITEFILE ("$t2<h2>p-values:</h2><br/>\n");
			}
			print WRITEFILE ("$t2<table class=\"results-table\">\n");
			print WRITEFILE ("$t2<tr>");
			foreach my $key (@keys) {
				print WRITEFILE "<th class=\"results-th\">".$key."</th>";
			}
			print WRITEFILE ("</tr>\n");
		}
		for my $i (0..$#{$table{"Gene"}}) {
			print WRITEFILE ("$t2<tr>");
			foreach my $key (@keys) {
				if ($key eq "Gene") {
					my $gene_format = $table{"Gene"}[$i];
					# Get rid of useless message for formatting
					$gene_format =~ s/_\(\+\+\+_See_Message_below\)//i;
					$gene_format =~ s/\+\+\+_Functional_tests_indicate_that_this_probe_has_some_level_of_background_which_may_be_corrected_prior_to_normalization\.__See_README\.txt_file_accompanying_RLF_on_USB_drive_for_additional_instructions//i;
					print WRITEFILE "<td class=\"results-gene-td\">".$gene_format."</td>";
				} elsif ($key eq $pvalue_header) {
					my $pvalue_format = sprintf("%0.5e", $table{$pvalue_header}[$i]);
					print WRITEFILE "<td class=\"results-td\">".$pvalue_format."</td>";
				} elsif ($key eq "Control Mean") {
					my $control_base_mean_format = sprintf("%0.5f", $table{"Control Mean"}[$i]);
					print WRITEFILE "<td class=\"results-td\">".$control_base_mean_format."</td>";
				} elsif ($key eq "Case Mean") {
					my $case_base_mean_format = sprintf("%0.5f", $table{"Case Mean"}[$i]);
					print WRITEFILE "<td class=\"results-td\">".$case_base_mean_format."</td>";
				} elsif ($key =~ m/Base Mean \d+/) {
					my $base_mean_format = sprintf("%0.5f", $table{$key}[$i]);
					print WRITEFILE "<td class=\"results-td\">".$base_mean_format."</td>";
				} elsif ($key eq "Fold Change") {
					my $fold_change_negative = 0;
					if ($table{"Fold Change"}[$i] =~ m/^-/) {
						$fold_change_negative = 1;
					}
					my $fold_change_format = $table{"Fold Change"}[$i];
					if ($table{"Fold Change"}[$i] =~ m/^(\+|-)?\d+\.?\d*$/) {
						$fold_change_format = sprintf("%0.5f", $table{"Fold Change"}[$i])
					}
					if (!$fold_change_negative) {
						$fold_change_format = "&nbsp;".$fold_change_format;
					}
					print WRITEFILE "<td class=\"results-td\">".$fold_change_format."</td>";
				} else {
					print WRITEFILE "<td class=\"results-td\">".$table{$key}[$i]."</td>";
				}
			}
			print WRITEFILE ("</tr>\n");
		}
		if (scalar(@{$table{"Gene"}}) > 0) {
			print WRITEFILE ("$t2</table>\n");
		}
	}
	print WRITEFILE <<ENDHTML2;
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
ENDHTML2
}

# Execute passed job
print STDERR format_localtime()."DEBUG: Processing job (job id = ".$job_id.", email = ".$email.", files = ".$files.", flags = ".$flags.")...\n";
my $line = "";
my $workdir = $work_path.$job_id."/";
# Correct flags
$flags =~ s/\\"/"/g;
# Call script with flags
my $script_cmd = "./heatmap_nanostring.pl ".$flags." --Rpackdir='".$Rpackages_dir."'";
my @args = ($script_cmd);
print STDERR format_localtime()."DEBUG: Starting script to normalize data and generate heatmap...\n";
system (@args);
# Wait for script to finish
my $pid = Unix::PID->new ();
$pid->wait_for_pidsof (
	{
		'get_pidof'	=> $script_cmd,
		'sleep_for'	=> 15, # in seconds
		#~ 'max_loops'	=> 40, # if not done, might be stuck
		#~ 'hit_max_loops' => sub {
			#~ kill (9, $pid->get_pidof($script_cmd, 1));
		#~ },
	}
);
# Clean up script pid file
unlink ($log_path.$job_id.'_execute.pid');
print STDERR format_localtime()."DEBUG: Script finished.\n";
# Rename files for chronological order
my $test = "";
my @output_files = glob ($workdir."*");
foreach my $file (@output_files) {
	if ($file =~ m/sorted_ttest/) {
		$test = "ttest";
	} elsif ($file =~ m/DESeq_normalized/) {
		$test = "DESeq";
	} elsif ($file =~ m/sorted_ANOVA/) {
		$test = "ANOVA";
	} elsif ($file =~ m/DESeq_ANODEV_normalized/) {
		$test = "ANOVAnegbin";
	}
}
@output_files = glob ($workdir."*.csv");
push (@output_files, glob ($workdir."*.tab"));
push (@output_files, glob ($workdir."*.txt"));
push (@output_files, glob ($workdir."*.png"));
foreach my $file (@output_files) {
	my $new_file = $file;
	$new_file =~ s/options\.txt/00a_-_options.txt/i;
	$new_file =~ s/warnings\.txt/00b_-_warnings.txt/i;
	$new_file =~ s/corrected_data\.(csv)|corrected_data\.(tab)/00c_-_corrected_data.$1/i;
	$new_file =~ s/raw_data\.(csv)|raw_data\.(tab)/00c_-_raw_data.$1/i;
	$new_file =~ s/housekeeping\.(csv)|housekeeping\.(tab)/00d_-_housekeeping.$1/i;
	$new_file =~ s/positive_normalized\.(csv)|positive_normalized\.(tab)/01_-_positive_corrected.$1/i;
	$new_file =~ s/negative_normalized\.(csv)|negative_normalized\.(tab)/02_-_negative_corrected.$1/i;
	$new_file =~ s/sample_content_normalized\.(csv)|sample_content_normalized\.(tab)/03_-_sample_content_normalized.$1/i;
	$new_file =~ s/DESeq_normalized\.(csv)|DESeq_normalized\.(tab)/01_-_DESeq_normalized.$1/i;
	$new_file =~ s/DESeq_ANODEV_normalized\.(csv)|DESeq_ANODEV_normalized\.(tab)/01_-_DESeq_ANODEV_normalized.$1/i;
	if (($test eq "ttest") || ($test eq "ANOVA")) {
		$new_file =~ s/sorted_(\w+)\.(csv)|sorted_(\w+)\.(tab)/04_-_sorted_$1.$2/i;
		$new_file =~ s/heatmap\.(csv)|heatmap\.(tab)/05a_-_heatmap.$1/i;
		$new_file =~ s/heatmap\.png/05b_-_heatmap.png/i;
	} elsif (($test eq "DESeq") || ($test eq "ANOVAnegbin")) {
		$new_file =~ s/sorted_(\w+)\.(csv)|sorted_(\w+)\.(tab)/02_-_sorted_$1.$2/i;
		$new_file =~ s/heatmap\.(csv)|heatmap\.(tab)/03a_-_heatmap.$1/i;
		$new_file =~ s/heatmap\.png/03b_-_heatmap.png/i;
	}
	rename ($file, $new_file);
}
# Process finished files, call send e-mail function, ADD send link to generated results page
# Define output zip file
my $zipfile = $workdir.$job_id.".zip";
# Get all output file types
@output_files = glob ($workdir."*.csv");
push (@output_files, glob ($workdir."*.tab"));
push (@output_files, glob ($workdir."*.txt"));
push (@output_files, glob ($workdir."*.png"));
# Create new zip file
print STDERR format_localtime()."DEBUG: Creating zip file for results...\n";
my $zip = Archive::Zip->new ();
# Add all output to the zip file
foreach my $file (@output_files) {
	$zip->addFile ($file, substr($file, length($workdir)));
}
# Save the zip file
$zip->writeToFileNamed ($zipfile);
#~ chmod (0644, $zipfile);
chmod (0666, $zipfile);
print STDERR format_localtime()."DEBUG: Results zip file written.\n";
# Read in warnings
my @warnings = ();
my $warning_file = $workdir."00b_-_warnings.txt";
print STDERR format_localtime()."DEBUG: Reading in warnings from file...\n";
open (READFILE, $warning_file);
	#~ or die "Please enter a valid filepath, stopped";
while ($line = <READFILE>) {
	$line =~ s/\r|\n//g;
	if ($line !~ m/^#/) {
		push (@warnings, $line);
	}
}
close (READFILE);
print STDERR format_localtime()."DEBUG: Number of warnings is ".scalar(@warnings).".\n";
# Generate table
print STDERR format_localtime()."DEBUG: Starting table of gene/p-value/fold change...\n";
my $sorted_file = "";
my $heatmap_file = "";
my $has_heatmap = 0;
@output_files = glob ($workdir."*");
foreach my $file (@output_files) {
	if ($file =~ m/sorted_ttest/) {
		$sorted_file = $file;
	} elsif ($file =~ m/sorted_DESeq/) {
		$sorted_file = $file;
	} elsif ($file =~ m/sorted_ANOVA/) {
		$sorted_file = $file;
	} elsif ($file =~ m/sorted_DESeq_ANODEV/) {
		$sorted_file = $file;
	} elsif ($file =~ m/heatmap/) {
		if ($file !~ m/heatmap\.png/) {
			$heatmap_file = $file;
		}
		if ($file =~ m/heatmap\.png/) {
			$has_heatmap = 1;
		}
	}
}
print STDERR format_localtime()."DEBUG: Test type is ".$test.".\n";
print STDERR format_localtime()."DEBUG: Results file is ".$sorted_file.".\n";
print STDERR format_localtime()."DEBUG: Heatmap file is ".$heatmap_file.".\n";
my $make_table;
my %table = ();
my @keys = ();
my $pvalue_header = '';
if ($adjpvalue eq "false") {
	$pvalue_header =  "p-value";
} elsif ($adjpvalue eq "true") {
	my $adjpvalue_header = '';
	if ($adjpvalue_type eq "bonferroni") {
		$adjpvalue_header = "Bonferroni";
	} elsif ($adjpvalue_type eq "holm") {
		$adjpvalue_header = "Holm";
	} elsif ($adjpvalue_type eq "hochberg") {
		$adjpvalue_header = "Hochberg";
	} elsif ($adjpvalue_type eq "hommel") {
		$adjpvalue_header = "Hommel";
	} elsif ($adjpvalue_type eq "BH") {
		$adjpvalue_header = "B&H";
	} elsif ($adjpvalue_type eq "BY") {
		$adjpvalue_header = "B&Y";
	}
	$pvalue_header = $adjpvalue_header." p-value";
}
if (($test eq "ttest") || ($test eq "DESeq")) {
	$table{"Gene"} = ();
	$table{$pvalue_header} = ();
	$table{"Control Mean"} = ();
	$table{"Case Mean"} = ();
	$table{"Fold Change"} = ();
	@keys = ("Gene", $pvalue_header, "Control Mean", "Case Mean", "Fold Change");
} elsif (($test eq "ANOVA") || ($test eq "ANOVAnegbin")) {
	$table{"Gene"} = ();
	$table{$pvalue_header} = ();
	@keys = ("Gene", $pvalue_header);
	for (my $i = 1; $i <= $ANOVA_features; $i++) {
		$table{"Base Mean $i"} = ();
		push(@keys, "Base Mean $i");
	}
}
if (($heatmap_file ne "") and ($has_heatmap)) {
	# Open heatmap file, get filtered genes
	my @line_array = ();
	my @filtered_gene = ();
	my $delimiter = "";
	if ($heatmap_file =~ m/\.csv$/) {
		$delimiter = ",";
	} elsif ($heatmap_file =~ m/\.tab$/) {
		$delimiter = "\t";
	}
	print STDERR format_localtime()."DEBUG: Delimiter pattern is /".$delimiter."/.\n";
	open (READFILE, $heatmap_file);
	while ($line = <READFILE>) {
		$line =~ s/\r|\n//g;
		@line_array = split (/$delimiter/, $line);
		if (length($line_array[0]) > 0) {
			$line_array[0] =~ s/^"|"$//g;
			push (@filtered_gene, $line_array[0]);
		}
	}
	close (READFILE);
	shift (@filtered_gene);
	print STDERR format_localtime()."DEBUG: Heatmap genes are (".join (',', @filtered_gene).").\n";
	if ($sorted_file =~ m/\.csv$/) {
		$delimiter = ",";
	} elsif ($sorted_file =~ m/\.tab$/) {
		$delimiter = "\t";
	}
	print STDERR format_localtime()."DEBUG: Delimiter pattern is /".$delimiter."/.\n";
	# Open sorted file
	open (READFILE, $sorted_file);
	# Read in column headers
	$line = <READFILE>;
	$line =~ s/\r|\n//g;
	my @header = split (/$delimiter/, $line);
	# Map headers to indices
	my %header_to_index = ();
	for my $i (1..$#header) {
		# Strip "
		my $filtered_header = $header[$i];
		$filtered_header =~ s/^"|"$//g;
		$header_to_index{"$filtered_header"} = $i;
	}
	print STDERR format_localtime()."DEBUG: Header to index hash is (";
	my $hash_size = keys (%header_to_index);
	my $hash_index = 0;
	while (my ($key, $value) = each (%header_to_index)) {
		$hash_index++;
		print STDERR $key." => ".$value;
		if ($hash_index < $hash_size) {
			print STDERR ", ";
		}
	}
	print STDERR ").\n";
	# Read rest of file, store in arrays
	while ($line = <READFILE>) {
		$line =~ s/\r|\n//g;
		@line_array = split (/$delimiter/, $line);
		# Strip "
		foreach my $i (0..$#line_array) {
			$line_array[$i] =~ s/^"|"$//g;
		}
		my $id = $line_array[$header_to_index{"id"}];
		if (grep {$_ eq $id} @filtered_gene) {
			if ($test eq "ttest") {
				push (@{$table{"Gene"}}, $line_array[$header_to_index{"id"}]);
				if ($adjpvalue eq "false") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value"}]);
				} elsif ($adjpvalue eq "true") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value.adj"}]);
				}
				push (@{$table{"Control Mean"}}, $line_array[$header_to_index{"baseMeanA"}]);
				push (@{$table{"Case Mean"}}, $line_array[$header_to_index{"baseMeanB"}]);
				push (@{$table{"Fold Change"}}, $line_array[$header_to_index{"foldChange"}]);
			} elsif ($test eq "DESeq") {
				push (@{$table{"Gene"}}, $line_array[$header_to_index{"id"}]);
				if ($adjpvalue eq "false") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"pval"}]);
				} elsif ($adjpvalue eq "true") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"padj"}]);
				}
				push (@{$table{"Control Mean"}}, $line_array[$header_to_index{"baseMeanA"}]);
				push (@{$table{"Case Mean"}}, $line_array[$header_to_index{"baseMeanB"}]);
				push (@{$table{"Fold Change"}}, $line_array[$header_to_index{"foldChange"}]);
			} elsif ($test eq "ANOVA") {
				push (@{$table{"Gene"}}, $line_array[$header_to_index{"id"}]);
				for (my $i = 1; $i <= $ANOVA_features; $i++) {
					push (@{$table{"Base Mean $i"}}, $line_array[$header_to_index{"baseMean$i"}]);
				}
				if ($adjpvalue eq "false") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value"}]);
				} elsif ($adjpvalue eq "true") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value.adj"}]);
				}
			} elsif ($test eq "ANOVAnegbin") {
				push (@{$table{"Gene"}}, $line_array[$header_to_index{"id"}]);
				for (my $i = 1; $i <= $ANOVA_features; $i++) {
					push (@{$table{"Base Mean $i"}}, $line_array[$header_to_index{"baseMean$i"}]);
				}
				if ($adjpvalue eq "false") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value"}]);
				} elsif ($adjpvalue eq "true") {
					push (@{$table{$pvalue_header}}, $line_array[$header_to_index{"p.value.adj"}]);
				}
			}
		}
	}
	close (READFILE);
	print STDERR format_localtime()."DEBUG: Table created.\n";
	$make_table = 1;
} else {
	print STDERR format_localtime()."DEBUG: Table could not be created.\n";
	$make_table = 0;
}
# Generate results page
my $results_file = $workdir."/index.html";
print STDERR format_localtime()."DEBUG: Generating HTML for results page...\n";
open (WRITEFILE, ">:utf8", $results_file);
printResultsPage ($workdir, $job_id, \@warnings, $test, $pvalue_header, $make_table, \%table, \@keys);
close (WRITEFILE);
#~ chmod (0644, $results_file);
chmod (0666, $results_file);
print STDERR format_localtime()."DEBUG: Results page generated.\n";
# Send output file to specified e-mail address
my $results_page = $base_url.'/result/'.$job_id.'/';
print STDERR format_localtime()."DEBUG: Preparing notifcation e-mail...\n";
my $msg = MIME::Lite->new (
	From		=> 'noreply@nanostride.soe.ucsc.edu',
	To			=> $email,
	Subject		=> 'NanoStriDE Results from '.$job_id,
	Type		=> 'multipart/mixed',
);
$msg->attach (
	Type		=> 'text/html',
	Data		=> '<html><body>The results of the job can be found here: <a href="'.$results_page.'">'.$job_id.'</a></body></html>'
);
$msg->send;
print STDERR format_localtime()."DEBUG: Notification e-mail sent.\n";
# Remove uploaded job files
print STDERR format_localtime()."DEBUG: Removing uploaded job files...\n";
my @input_files = split (/,/, $files);
#~ unlink (@input_files);
print STDERR format_localtime()."DEBUG: Uploaded files removed.\n";

print STDERR format_localtime()."DEBUG: Job done.\n";
exit (0);
