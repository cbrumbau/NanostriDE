#!/usr/bin/perl
##
# heatmap_nanostring.pl
# 
# Process raw data files from Nanostring platform by spike normalizing the raw
# data and normalizing the processed data to the negative binomial distribution
# in order to process the data and generate a differential expression heatmap
# for the provided data and given conditions.
# 
# Use Statistics::R module to use R instead of using R scripts.
# 
# Generates a PNG of the heatmap given the raw data files.
# 
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 02/09/2011
##

# Add local libraries
BEGIN {
	push (@INC, "./lib");
}

use warnings;
use strict;
use Getopt::Long;
use File::Path qw(make_path);
use Statistics::R;
use Unix::PID;
use NanoString::RCC; # local module
use NanoString::Corrections; # local module
use NanoString::TTest; # local module
use NanoString::DESeq; # local module
use NanoString::ANOVA; # local module
use NanoString::ANOVAnegbin; # local module

# Set up parameters
my @rawdata_files = ();
my $rawdata_dir = '';
my @rawdata_labels = ();
my @rawdata_conds = ();
my $data_type = 'miRNA';
my $correction_type = 'mouse'; # Currently accepts: human, mouse
my $normalize_samplecontent;
my $negative_type = 2;
my $negative4_ttest_pvalue = 0.05;
my @negative4_replicates = (); # option has no effect yet, currently processes all samples
my $samplecontent_type = 2;
my $samplecontent3_columntosort = 1;
my $samplecontent3_topcounts = 75;
my $output_dir = '/tmp/nanostring_output/'; # needs to be a FULL PATH else goes whereever R was invoked from...
my $test_type = 'DESeq'; # Currently accepts: ttest, DESeq, ANOVA, ANOVAnegbin
my $adjpvalue_cutoff = 0.05;
my $mean_cutoff = 0.0;
my $adjpvalue;
my $adjpvalue_type = 'BH'; # Currently accepts: holm, hochberg, hommel, bonferroni, BH, BY, fdr
my $heatmap_clustercols = 'cluster_cols = TRUE';
my $heatmap_key = 'legend = FALSE';
my $heatmap_colors = 'colorRampPalette(c("green", "black", "red"))(100)';
my $R_data_output = '';
my $R_norm_output = '';
my $tabdelimited_output;
my $install_Rpackages; # can't catch errors for missing target packages in Bioconductor, safer to install manually in R instance?
my $R_packages_dir = '';
my $R_log_dir_base = "/tmp/Statistics-R/";
my $R_log_dir = '';
my $warnings = 1;
my $warnings_file = 'warnings.txt';
our $debug = 0;
our $debug_verbosity = 3;
my $args = GetOptions ("inputfile|f=s"			=> \@rawdata_files,
						"inputdir|d=s"			=> \$rawdata_dir,
						"labels|l=s"			=> \@rawdata_labels,
						"conditions|c=s"		=> \@rawdata_conds,
						"datatype=s"			=> \$data_type,
						"correctiontype=s"		=> \$correction_type,
						"normalizecontent|z"	=> \$normalize_samplecontent,
						"negative|n=i"			=> \$negative_type,
						"neg4ttestpval=f"		=> \$negative4_ttest_pvalue,
						"neg4replicates=i"		=> \@negative4_replicates,
						"samplecontent|s=i"		=> \$samplecontent_type,
						"sc3columntosort=i"		=> \$samplecontent3_columntosort,
						"sc3topcounts=i"		=> \$samplecontent3_topcounts,
						"outputdir|o=s"			=> \$output_dir,
						"testtype|t=s"			=> \$test_type,
						"pvaluecutoff=f"		=> \$adjpvalue_cutoff,
						"meancutoff=f"			=> \$mean_cutoff,
						"adjpvalue"				=> \$adjpvalue,
						"adjpvaluetype=s"		=> \$adjpvalue_type,
						"heatmapclustercols=s"	=> \$heatmap_clustercols,
						"heatmapkey=s"			=> \$heatmap_key,
						"heatmapcolors=s"		=> \$heatmap_colors,
						"Rdataoutput=s"			=> \$R_data_output,
						"Rnormoutput=s"			=> \$R_norm_output,
						"taboutput"				=> \$tabdelimited_output,
						"installRpack"			=> \$install_Rpackages,
						"Rpackdir=s"			=> \$R_packages_dir,
						"Rlogdir=s"				=> \$R_log_dir,
						"warnings=i"			=> \$warnings,
						"warningsfile=s"		=> \$warnings_file,
						"debug=i"				=> \$debug,
						"debugverbose=i"		=> \$debug_verbosity);

# Subroutines

# max_length_line_by_chars ($line, $max_length, $character_array_ref)
# Formats a string into substrings of up to int max_length characters by the
#	furthest valid character identified
# Input: $line:			 a string that is to be divided into substrings
#		$max_length:	 an int with the maximum length of the substrings
#		$characters_ref: a reference to an array of valid characters to use
#						 to subdivide string into substrings
# Return: A reference to an array containing the substrings
sub max_length_line_by_chars {
	my $line = shift;
	my $max_length = shift;
	my $characters_ref = shift;
	my @characters = @{$characters_ref};
	my @stored_lines = ();
	# Store at int max_length characters or less
	while (length ($line) > $max_length) {
		# Trim and store into array
		my $temp_line = substr ($line, 0, $max_length-1);
		# Cut at furthermost acceptable character for new line
		# Use characters in characters array
		my @positions = ();
		foreach my $char (@characters) {
			push (@positions, rindex ($temp_line, $char));
		}
		@positions = sort {$a <=> $b} @positions; # numerically sort ascending
		# Do anything if all rindex () return -1 (no char found)?
		my $max_position = $positions[-1]+1;
		push (@stored_lines, substr ($line, 0, $max_position));
		$line = substr ($line, $max_position);
	}
	# Add leftover last line
	if (length ($line) > 0) {
		push (@stored_lines, $line);
	}

	return \@stored_lines;
}

# format_dataframe_R ($data_set_ref, $var_name)
# Formats a data set array containing column and row names
#	to a string that can be sent to R by Statistics::R or
#	used in a R script
# Input: $data_set_ref: a reference to an array containing a data set with
#					column and row names
#		$var_name:	a string contaning what variable name to use for the
#					data set in R, user should ensure name is not a
#					keyword in R
# Return: A string containing a R command to create a data frame for the given
#			data set and setting the data frame to the passed variable name
sub format_dataframe_R {
	my $data_set_ref = shift;
	my @data_set = @{$data_set_ref};
	my $var_name = shift;
	my @data_set_transpose = ();
	my @row_names = ();
	my $max_length = 1024; # max per line in R console is 1024
	my @chars = (' (', ')', ','); # split on ' (' ')' and ','
	my @formatted_input = ();
	my $formatted_input_line = $var_name." <- data.frame(";
	# Do matrix transpose to get the columns (samples) as rows to read for data
	# frame a column at a time
	for my $i (0..$#data_set) {
		my @row = @{$data_set[$i]};
		for my $j (0..$#row) {
			$data_set_transpose[$j][$i] = $data_set[$i][$j];
		}
	}
	undef @data_set;
	undef $data_set_ref;
	# Generate data frame for R
	for my $i (0..$#data_set_transpose) {
		my @row = @{$data_set_transpose[$i]};
		if ($i == 0) {
			# Handle first matrix row with row names
			@row_names = @row[1..$#row]; # get slice without "Name"
		} else {
			push (@formatted_input, @{max_length_line_by_chars ($formatted_input_line, $max_length, \@chars)});
			$formatted_input_line = pop (@formatted_input);
			$formatted_input_line = $formatted_input_line."'".$row[0]."'=c(".join (",", @row[1..$#row]).")";
			if ($i < $#data_set_transpose) {
				# Do not add comma after last column entry
				$formatted_input_line = $formatted_input_line.",";
			}
		}
	}
	$formatted_input_line = $formatted_input_line.");";
	push (@formatted_input, @{max_length_line_by_chars ($formatted_input_line, $max_length, \@chars)});
	# Add R code for row names, wrap strings in single quotes
	# Since it is an array of strings in quotes, input can be wrapped to next
	# line and R should not complain
	$formatted_input_line = "rownames(".$var_name.") <- c('".join ("','", @row_names)."');\n";
	push (@formatted_input, @{max_length_line_by_chars ($formatted_input_line, $max_length, \@chars)});

	return join ("\n", @formatted_input);
}

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

# Install R packages if requested and exit
if ($install_Rpackages) {
	my $R = Statistics::R->new ();
	$R->startR ();
	# Get DESeq for negative binomial normalization
	$R->send ('source("http://www.bioconductor.org/biocLite.R");');
	$R->send ('biocLite("DESeq");');
	# Get gplots for heatmap plotting
	$R->send ('install.packages("gplots");');
	# Stop R and exit
	$R->stopR ();
	exit (0);
}

# Set debug flag in modules
NanoString::RCC->setDebug ($debug);
NanoString::RCC->setDebugVerbosity ($debug_verbosity);
NanoString::Corrections->setDebug ($debug);
NanoString::Corrections->setDebugVerbosity ($debug_verbosity);

# Set R log dir if not provided
if ($R_log_dir eq '') {
	my @time_data = localtime(time);
	$time_data[5] += 1900;
	my $join_time = join ('-', @time_data);
	$R_log_dir = $join_time."_".int(rand(4096));
}

# Create dirs for R log if necessary
# Otherwise Statistics::R hangs
make_path ($R_log_dir_base);

# Prepare datatype, either mRNA or miRNA
if (! (grep {$_ eq $data_type} ("mRNA", "miRNA"))) {
	print STDERR format_localtime()."ERROR: Data type not of mRNA or miRNA!\nData type is: ".$data_type."\n";
	exit (1);
}

# Check adjusted p-value type, must belong to: holm, hochberg, hommel, bonferroni, BH, BY, fdr
if (! (grep {$_ eq $adjpvalue_type} ("holm", "hochberg", "hommel", "bonferroni", "BH", "BY", "fdr"))) {
	print STDERR format_localtime()."ERROR: Adjusted p-value type not a valid adjustment type!\nAdjusted p-value type is: ".$adjpvalue_type."\n";
	exit (1);
}

# Process input dir if given
if ($rawdata_dir !~ m/^\s*$/) {
	@rawdata_files = glob ($rawdata_dir.'*.RCC');
}

# Merge options passed to script
@rawdata_files = split (/,/, join (',', @rawdata_files));
@rawdata_labels = split (/,/, join (',', @rawdata_labels));
@rawdata_conds = split (/,/, join (',', @rawdata_conds));
@negative4_replicates = split (/,/, join (',', @negative4_replicates));
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: rawdata_files =\n";
	foreach my $file (@rawdata_files) {
		print STDERR "$file ";
	}
	print STDERR "\n";
	print STDERR format_localtime()."DEBUG: rawdata_labels =\n";
	foreach my $label (@rawdata_labels) {
		print STDERR "$label ";
	}
	print STDERR "\n";
	print STDERR format_localtime()."DEBUG: rawdata_conds =\n";
	foreach my $cond (@rawdata_conds) {
		print STDERR "$cond ";
	}
	print STDERR "\n";
	print STDERR format_localtime()."DEBUG: negative4_replicates =\n";
	foreach my $label (@negative4_replicates) {
		print STDERR "$label ";
	}
	print STDERR "\n";
}

# Sanitize labels
# Cannot have whitespaces for data frame column names in R
for my $i (0..$#rawdata_labels) {
	if ($rawdata_labels[$i] =~ m/^\d/) {
		$rawdata_labels[$i] = "sample_number__".$rawdata_labels[$i];
	}
	$rawdata_labels[$i] =~ s/\s/_/g;
}

# Set warning option
$warnings_file = $output_dir.$warnings_file;

# Process warnings
my @rawdata_names = ();
if ($warnings) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing warnings types 1 and 2...\n";
	}
	open (WRITEFILE, ">:utf8", $warnings_file);
		#~ or die format_localtime()."ERROR: Please enter a valid filepath ($warnings_file), stopped";
	print WRITEFILE "# Check for warnings\n";
	print WRITEFILE "# 1. FOVCounted to FOVCount ratio; flag if less than 80%\n";
	print WRITEFILE "# 2. Binding density - should be between 0.05 and 2.25; flag if not\n";
	foreach my $path (@rawdata_files) {
		my $RCC = NanoString::RCC->new ($path);
		my $file = $path;
		$file =~ s/^.*\///; # strip leading path
		push (@rawdata_names, '"'.$file.'"');
		# Check for warnings
		# 1. FOVCount to FOVCounted ratio; flag if less than 80%
		my $fovCount_fovCounted_ratio = (($RCC->getValue ("Lane_Attributes", "FovCounted")) / ($RCC->getValue ("Lane_Attributes", "FovCount")));
		if ($fovCount_fovCounted_ratio < 0.8) {
			print WRITEFILE "WARNING: ".$file." has FOVCount/FOVCounted < 80% (".($fovCount_fovCounted_ratio * 100)."%).\n";
		}
		# 2. Binding density - should be between 0.05 and 2.25; flag if not
		my $binding_density = $RCC->getValue ("Lane_Attributes", "BindingDensity");
		if ($binding_density < 0.05) {
			print WRITEFILE "WARNING: ".$file." has binding density < 0.05 (".$binding_density.").\n";
		} elsif ($binding_density > 2.25) {
			print WRITEFILE "WARNING: ".$file." has binding density > 2.25 (".$binding_density.").\n";
		}
	}
	close (WRITEFILE);
}

# Read in raw data, store in array
my @all_RCC = ();
foreach my $path (@rawdata_files) {
	push (@all_RCC, NanoString::RCC->new ($path));
	if ($data_type eq "miRNA") {
		my $corrected_data_ref = NanoString::Corrections->applyCorrections (\@{$all_RCC[-1]->getRawData ()}, $correction_type, $all_RCC[-1]->getValue ("Lane Attributes", "FovCounted"));
		my $temp_RCC = pop(@all_RCC);
		$temp_RCC = $temp_RCC->setRawData ($corrected_data_ref);
		push(@all_RCC, $temp_RCC);
	}
}
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Number of files read in: ".scalar (@all_RCC)."\n";
}

# Merge all data
my $first_RCC = shift (@all_RCC);
my $merged_data_ref = $first_RCC->mergeData (\@all_RCC, \@rawdata_labels);
my @merged_data = @{$merged_data_ref};
undef @all_RCC; # free up memory (now that raw data has been merged)
undef @rawdata_labels; # free up memory (now that labels have no more use)

# Generate classifications
$first_RCC = $first_RCC->classifyData ();

# Separate positive/negative/housekeeping classifications from raw data
my @filter = ("Positive", "Negative", "Housekeeping");
my $filtered_data_ref = $first_RCC->getFilteredData (\@merged_data, \@filter, 0);
my @filtered_data = @{$filtered_data_ref};

# Separate raw data classifications from positive/negative/housekeeping
@filter = ("Positive", "Negative", "Housekeeping");
my %normalize_genes = ();
foreach my $norm_class (@filter) {
	my @norm_class_array = ($norm_class);
	my $filtered_norm_class_ref = $first_RCC->getFilteredData (\@merged_data, \@norm_class_array, 1);
	my @row = @{$filtered_norm_class_ref};
	for my $i (0..$#row) {
		my @col = @{$row[$i]};
		for my $j (0..$#col) {
			$normalize_genes{$norm_class}[$i][$j] = $col[$j];
		}
	}
}

# Free up memory
undef $first_RCC;
undef @merged_data;
undef $merged_data_ref;
undef @filter;

# Prepare filtered data for R to perform calculations
my $R_command = format_dataframe_R (\@filtered_data, "rna");
undef @filtered_data; # free up memory

# Prepare filtered normalizing data for R to perform calculations
my $R_normalize = format_dataframe_R (\@{$normalize_genes{"Positive"}}, "positive");
$R_normalize = $R_normalize."\n".format_dataframe_R (\@{$normalize_genes{"Negative"}}, "negative");
$R_normalize = $R_normalize."\n".format_dataframe_R (\@{$normalize_genes{"Housekeeping"}}, "housekeeping");
undef %normalize_genes; # free up memory

if ($debug > 1) {
	print STDERR format_localtime()."DEBUG: R command for data frame with data:\n".$R_command;
	print STDERR format_localtime()."DEBUG: R command for data frame with normalizing data:\n".$R_normalize;
} elsif ($debug > 0) {
	print STDERR format_localtime()."DEBUG: R command for data frame with data:\n".substr ($R_command, 0, $debug_verbosity*10-1)." ... ".substr ($R_command, length ($R_command)-$debug_verbosity*10-1);
	print STDERR format_localtime()."DEBUG: R command for data frame with normalizing data:\n".substr ($R_normalize, 0, $debug_verbosity*10-1)." ... ".substr ($R_normalize, length ($R_normalize)-$debug_verbosity*10-1);
}

# Print out R command if requested
if (length ($R_data_output) > 0) {
	print STDERR format_localtime()."DEBUG: Writing R command for data frame with data to file...\n";
	open (RCFILE, ">", $output_dir.$R_data_output);
		#~ or die format_localtime()."ERROR: Please enter a valid filepath ($R_data_output), stopped";
	print RCFILE $R_command;
	close (RCFILE);
}

# Print out R normalizing genes if requested
if (length ($R_norm_output) > 0) {
	print STDERR format_localtime()."DEBUG: Writing R command for data frames with normalizing data to file...\n";
	open (RCFILE, ">", $output_dir.$R_norm_output);
		#~ or die format_localtime()."ERROR: Please enter a valid filepath ($R_norm_output), stopped";
	print RCFILE $R_normalize;
	close (RCFILE);
}

# Start R
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Starting R...\n";
	print STDERR format_localtime()."DEBUG: Setting R log dir to ".$R_log_dir_base.$R_log_dir."...\n";
}
mkdir ($R_log_dir_base.$R_log_dir, 0777);
my $R = Statistics::R->new ('log_dir' => $R_log_dir_base.$R_log_dir);
$R->startR ();
$R->lock ();
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Sending variables to R...\n";
}
$R->send ($R_command);
$R->send ($R_normalize);
undef $R_command; # free up memory, sent to R
undef $R_normalize; # free up memory, sent to R
my $timeout = 20;
# Note: R does garbage collection only when it needs to free up memory

# Set R library packages path if requested
if ($R_packages_dir !~ m/^\s*$/) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Adding ".$R_packages_dir." to the R library paths...\n";
	}
	$R->send ('.libPaths(c("'.$R_packages_dir.'", .libPaths()))');
}

# Store file names in vector if warnings
if ($warnings) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Storing (".join (', ', @rawdata_names).") file names for warnings ...\n";
	}
	$R->send ('file_names <- c('.join (', ', @rawdata_names).')');
}

# Output corrected data to file
if ($tabdelimited_output) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing corrected data to tab delimited file...\n";
	}
	$R->send ('write.table(rna, file = "'.$output_dir.'corrected_data.tab", sep = "\t");');
} else {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing corrected data to csv file...\n";
	}
	$R->send ('write.csv(rna, file = "'.$output_dir.'corrected_data.csv");');
}
# Control count normalization - positive/negative counts
# Positive control count
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Processing positive normalization...\n";
}
$R->send ('# Sum each sample/column for positive total counts
pos_col_sum <- colSums(positive);
# Obtain the total mean for positive total counts
pos_total_mean <- sum(positive)/ncol(positive);
# Calculate the normalization factor for each sample/column
pos_norm <- c();
pos_norm <- pos_total_mean/pos_col_sum;
# Apply normalization factor by multiplying with raw data
pos_rna <- rna; # copy rna to get col and row names
# apply to rna
for (i in c(1:nrow(rna))) {
	for (j in c(1:ncol(rna))) {
		pos_rna[i,j] <- rna[i,j]*pos_norm[j];
	}
}
# apply to negative
for (i in c(1:nrow(negative))) {
	for (j in c(1:ncol(negative))) {
		negative[i,j] <- negative[i,j]*pos_norm[j];
	}
}
# apply to housekeeping
for (i in c(1:nrow(housekeeping))) {
	for (j in c(1:ncol(housekeeping))) {
		housekeeping[i,j] <- housekeeping[i,j]*pos_norm[j];
	}
}');
# Process warnings
if ($warnings) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing warnings type 3...\n";
	}
	# 3. Positive control normalization - factor should be between 0.3 and 3; flag if not
	$R->send ('# 3. Positive control normalization - factor should be between 0.3 and 3; flag if not
	warnings <- c("# 3. Positive control normalization - factor should be between 0.3 and 3; flag if not");
	for (i in c(1:length(pos_norm))) {
		if (pos_norm[i] < 0.3) {
			warnings <- append(warnings, paste("WARNING:", file_names[i], "has positive control normalization factor < 0.3 (", pos_norm[i], ")."));
		} else if (pos_norm[i] > 3) {
			warnings <- append(warnings, paste("WARNING:", file_names[i], "has positive control normalization factor > 3 (", pos_norm[i], ")."));
		}
	}
	if (length(warnings) > 0) {
		FILEWRITE <- file("'.$warnings_file.'", open = "a");
		writeLines(warnings, FILEWRITE);
		close(FILEWRITE);
	}');
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing warnings type 4...\n";
	}
	# 4. 0.5fM control counts should be above average of negative controls in 90% of lanes
	$R->send ('# 4. 0.5fM control counts should be above average of negative controls in 90% of lanes
	warnings <- c("# 4. 0.5fM control counts should be above average of negative controls in 90% of lanes");
	lanes <- c();
	half.fM <- c();
	neg.count.mean <- c();
	for (i in c(1:ncol(negative))) {
		negative_mean <- sum(negative[,i]) / nrow(negative);
		if (negative_mean > positive[\'POS_E(0.5)\', i]) {
			lanes <- append(lanes, file_names[i]);
			half.fM <- append(half.fM, positive[\'POS_E(0.5)\', i]);
			neg.count.mean <- append(neg.count.mean, negative_mean);
		}
	}
	if ((length(lanes) / length(file_names)) > 0.1) {
		warnings <- append(warnings, paste("WARNING:", lanes, "has 0.5fM control counts (", half.fM, ") below average of negative controls (", neg.count.mean, ")."));
	}
	if (length(warnings) > 0) {
		FILEWRITE <- file("'.$warnings_file.'", open = "a");
		writeLines(warnings, FILEWRITE);
		close(FILEWRITE);
	}');
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing warnings type 5...\n";
	}
	# 5. Linear correlation of positive controls vs concentration should have R^2 greater than 0.95 in at least 90% of lanes
	$R->send ('# 5. Linear correlation of positive controls vs concentration should have R^2 greater than 0.95 in at least 90% of lanes
	warnings <- c("# 5. Linear correlation of positive controls vs concentration should have R^2 greater than 0.95 in at least 90% of lanes");
	r2 <- c();
	r2.val <- c();
	# Extract concentrations
	conc <- as.numeric(gsub("[^0-9.]", "", rownames(positive)));
	# Process linear correlation for every column
	for (i in c(1:ncol(positive))) {
		pos_df <- data.frame(conc = conc, count = positive[,i]);
		positive.lm <- lm(formula = conc ~ count, data = pos_df);
		if (summary(positive.lm)$r.squared < 0.95) {
			r2 <- append(r2, file_names[i]);
			r2.val <- append(r2.val, summary(positive.lm)$r.squared);
		}
	}
	if ((length(r2) / length(file_names)) > 0.1) {
		warnings <- append(warnings, paste("WARNING: Linear correlation of positive controls vs concentration in", r2, "has R^2 less than 0.95 (", r2.val, ")."));
	}
	if (length(warnings) > 0) {
		FILEWRITE <- file("'.$warnings_file.'", open = "a");
		writeLines(warnings, FILEWRITE);
		close(FILEWRITE);
	}');
}
# Output positive normalized data to file
if ($tabdelimited_output) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing positive normalization to tab delimited file...\n";
	}
	$R->send ('write.table(pos_rna, file = "'.$output_dir.'positive_normalized.tab", sep = "\t");');
} else {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing positive normalization to csv file...\n";
	}
	$R->send ('write.csv(pos_rna, file = "'.$output_dir.'positive_normalized.csv");');
}
# Negative control count
# Several options for negative control count normalization
# Any count below the calculated is considered undetectable
my $negative_threshold = 0;
$R->send('neg_rna <- rna; # copy rna to get col and row names');
if ($negative_type == 1) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing negative normalization type 1...\n";
	}
	# 1. Sum each sample/column for negative control counts and use mean
	$R->send ('neg_col_mean <- colMeans(negative);
	for (i in c(1:nrow(rna))) {
		for (j in c(1:ncol(rna))) {
			neg_rna[i,j] <- pos_rna[i,j]-neg_col_mean[j];
		}
	}');
} elsif ($negative_type == 2) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing negative normalization type 2...\n";
	}
	# 2. Calculate the standard deviation for each column and calculate two
	# standard deviations above the mean
	$R->send ('neg_col_mean <- colMeans(negative);
	neg_col_sd <- c();
	for (j in c(1:ncol(negative))) {
		neg_col_sd[j] <- sd(negative[,j]);
	}
	for (i in c(1:nrow(rna))) {
		for (j in c(1:ncol(rna))) {
			neg_rna[i,j] <- pos_rna[i,j]-(neg_col_mean[j]+2*neg_col_sd[j]);
		}
	}');
} elsif ($negative_type == 3) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing negative normalization type 3...\n";
	}
	# 3. Maximum value of negative controls
	$R->send ('neg_col_max <- c();
	for (j in c(1:ncol(negative))) {
		neg_col_max[j] <- max(negative[,j]);
	}
	for (i in c(1:nrow(rna))) {
		for (j in c(1:ncol(rna))) {
			neg_rna[i,j] <- pos_rna[i,j]-neg_col_max[j];
		}
	}');
} elsif ($negative_type == 4) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing negative normalization type 4...\n";
	}
	# 4. Perform a one tailed Student's t-test (with default p-value=0.05)
	$R->send ('posrna_row_mean <- rowMeans(pos_rna);
	for (i in (1:nrow(pos_rna))) {
		t_test <- t.test(negative,y=pos_rna[i,],alternative="less");
		if (t_test$p.value < '.$negative4_ttest_pvalue.') {
			for (j in (1:ncol(pos_rna))) {
				neg_rna[i,j] <- pos_rna[i,j]-posrna_row_mean[i];
			}
		} else {
			for (j in (1:ncol(pos_rna))) {
				neg_rna[i,j] <- 0;
			}
		}
	}');
}
# Pull values <= 0 in neg_rna up to 0
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Processing negative normalization values below zero...\n";
}
$R->send ('# set any values below 0 to 0
for (i in (1:nrow(neg_rna))) {
	for (j in (1:ncol(neg_rna))) {
		if (neg_rna[i,j] <= 0) {
			neg_rna[i,j] <- 0;
		}
	}
}');
# Output negative normalized data to file
if ($tabdelimited_output) {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing negative normalization to tab delimited file...\n";
	}
	$R->send ('write.table(neg_rna, file = "'.$output_dir.'negative_normalized.tab", sep = "\t");');
} else {
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Writing negative normalization to csv file...\n";
	}
	$R->send ('write.csv(neg_rna, file = "'.$output_dir.'negative_normalized.csv");');
}

if ($normalize_samplecontent) {
	$R->send('norm_rna <- rna; # copy rna to get col and row names');
	if ($samplecontent_type == 1) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Processing sample content normalization type 1...\n";
		}
		# 1. Normalize for sample content with housekeeping genes (mRNA) 
		$R->send ('# Sum each column for housekeeping total counts
		house_col_sum <- colSums(housekeeping);
		# Obtain the total mean for housekeeping total counts
		house_total_mean <- sum(housekeeping)/ncol(housekeeping);
		# Calculate the normalization factor for each column
		house_norm <- c();
		house_norm <- house_total_mean/house_col_sum;
		# Apply normalization factor by multiplying with raw data
		# apply to neg_rna
		for (i in c(1:nrow(neg_rna))) {
			for (j in c(1:ncol(neg_rna))) {
				norm_rna[i,j] <- neg_rna[i,j]*house_norm[j];
			}
		}');
	} elsif ($samplecontent_type == 2) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Processing sample content normalization type 2...\n";
		}
		# 2. Normalize for sample content with entire sample (miRNA)
		$R->send ('# Sum each column for all miRNA total counts
		negrna_col_sum <- colSums(neg_rna);
		# Obtain the total mean for all total counts
		negrna_total_mean <- sum(neg_rna)/ncol(neg_rna);
		# Calculate the normalization factor for each column
		negrna_norm <- c();
		negrna_norm <- negrna_total_mean/negrna_col_sum;
		# Apply normalization factor by multiplying with raw data
		# apply to neg_rna
		for (i in c(1:nrow(neg_rna))) {
			for (j in c(1:ncol(neg_rna))) {
				norm_rna[i,j] <- neg_rna[i,j]*negrna_norm[j];
			}
		}');
	} elsif ($samplecontent_type == 3) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Processing sample content normalization type 3...\n";
		}
		# 3. Normalize for sample content with highest miRNAs in sample (miRNA)
		$R->send ('# Sort the data by one column in descending order
		sort.neg_rna <- neg_rna[order(-neg_rna[,'.$samplecontent3_columntosort.'])];
		# Take the first top count rows to work with
		sort.neg_rna <- sort.neg_rna[1:'.$samplecontent3_topcounts.',]
		# Sum each column for selected total counts
		sortnegrna_col_sum <- colSums(sort.neg_rna);
		# Obtain the average total for selected total counts
		sortnegrna_total_mean <- sum(sort.neg_rna)/ncol(sort.neg_rna);
		# Calculate the normalization factor for each column
		sortnegrna_norm <- c();
		sortnegrna_norm <- sortnegrna_total_mean/sortnegrna_col_sum;
		# Apply normalization factor by multiplying with raw data
		# apply to neg_rna
		for (i in c(1:nrow(neg_rna))) {
			for (j in c(1:ncol(neg_rna))) {
				norm_rna[i,j] <- neg_rna[i,j]*sortnegrna_norm[j];
			}
		}');
	}
	# Output sample content normalized data to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sample content normalization to tab delimited file...\n";
		}
		$R->send ('write.table(norm_rna, file = "'.$output_dir.'sample_content_normalized.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sample content normalization to csv file...\n";
		}
		$R->send ('write.csv(norm_rna, file = "'.$output_dir.'sample_content_normalized.csv");');
	}
} else {
	# Set negative normalized to normalized data frame
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Setting negative normalization to normalized data to analyze...\n";
	}
	$R->send ('norm_rna <- neg_rna;');
}

# Remove rows that have 0 total counts
#if ($debug > 0) {
#	print STDERR format_localtime()."DEBUG: Removing genes that have zero counts across all samples...\n";
#}
#$R->send ('# remove any rows that sum to 0
#norm_rna <- norm_rna[rowSums(norm_rna) > 0, ];');

# Check for test specified and generate heatmap if test_type is valid
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Starting test to generate heatmap...\n";
}
if ($test_type eq 'ttest') {
	NanoString::TTest->setDebug ($debug);
	NanoString::TTest->setDebugVerbosity ($debug_verbosity);
	NanoString::TTest->applyTTest ($R, \@rawdata_conds, $tabdelimited_output, $output_dir, $adjpvalue_cutoff, $mean_cutoff, $adjpvalue, $adjpvalue_type);
	NanoString::TTest->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);
} elsif (($test_type eq 'DESeq') && (!$normalize_samplecontent)) { # Don't normalize to content twice
	NanoString::DESeq->setDebug ($debug);
	NanoString::DESeq->setDebugVerbosity ($debug_verbosity);
	NanoString::DESeq->applyDESeq ($R, \@rawdata_conds, $tabdelimited_output, $output_dir, $adjpvalue_cutoff, $mean_cutoff, $adjpvalue, $adjpvalue_type);
	NanoString::DESeq->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);
} elsif ($test_type eq 'ANOVA') {
	NanoString::ANOVA->setDebug ($debug);
	NanoString::ANOVA->setDebugVerbosity ($debug_verbosity);
	NanoString::ANOVA->applyANOVA ($R, \@rawdata_conds, $tabdelimited_output, $output_dir, $adjpvalue_cutoff, $mean_cutoff, $adjpvalue, $adjpvalue_type);
	NanoString::ANOVA->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);
} elsif ($test_type eq 'ANOVAnegbin') {
	NanoString::ANOVAnegbin->setDebug ($debug);
	NanoString::ANOVAnegbin->setDebugVerbosity ($debug_verbosity);
	NanoString::ANOVAnegbin->applyANOVA ($R, \@rawdata_conds, $tabdelimited_output, $output_dir, $adjpvalue_cutoff, $mean_cutoff, $adjpvalue, $adjpvalue_type);
	NanoString::ANOVAnegbin->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);
} else {
	print STDERR format_localtime()."ERROR: No valid test chosen for heatmap generation.\n";
}

# Stop R and exit
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Stopping R...\n";
}
$R->stopR ();
# Wait for R to finish
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Waiting for R to close...\n";
}
my $pid = Unix::PID->new ();
my $R_pid = $pid->get_pid_from_pidfile($R_log_dir_base.$R_log_dir.'/R.pid');
$pid->wait_for_pidsof (
	{
		'pid_list'	=> ($R_pid),
		'sleep_for'	=> 15, # in seconds
		'max_loops'	=> 4, # if not done, might be stuck
		'hit_max_loops' => sub {
			$pid->kill(9, $R_pid);
		},
	}
);
# Clean up log directory for Statistics::R
if ($debug > 0) {
	print STDERR format_localtime()."DEBUG: Cleaning up R log directories...\n";
}
rmdir ($R_log_dir_base.$R_log_dir."/output");
rmdir ($R_log_dir_base.$R_log_dir);
exit (0);
