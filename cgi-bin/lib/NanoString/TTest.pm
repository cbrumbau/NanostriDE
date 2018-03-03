#!/usr/bin/perl
##
# NanoString/TTest.pm
# 
# Perl module to perform t-test to generate p-values and generates a heatmap.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 03/10/2011
##

package NanoString::TTest;

use strict;
use warnings;

our $VERSION = 1.0;
our $debug = 0;
our $debug_verbosity = 3;


sub setDebug {
	my ($package, $level) = @_;
	$debug = $level;
}

sub setDebugVerbosity {
	my ($package, $lines) = @_;
	$debug_verbosity = $lines;
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

=head1 NAME
 
	NanoString::TTest - Generates p-values from NanoString data and generates
	a heatmap from this normalized data.

=head1 SYNOPSIS

	use NanoString::TTest;
	NanoString::TTest->applyTTest ($R, $raw_conds_ref, $tabdelimited_output, $output_dir, $ttest_pvalue_cutoff, $ttest_mean_cutoff, $pvalue, $adjpvalue_type);
	NanoString::TTest->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);

=head1 DESCRIPTION

This is a library which generates p-values for normalized NanoString data by
t-test and generates a heatmap.

=head2 Methods

=head3 applyTTest

	NanoString::TTest->applyTTest ($R, $raw_conds_ref, $tabdelimited_output, $output_dir, $ttest_pvalue_cutoff, $ttest_mean_cutoff, $pvalue, $adjpvalue_type);

Takes a R session reference, a flag to designate tab delimited output,
the path to the output directory.

=cut

sub applyTTest {
	my $package = shift;
	my $R = shift;
	my $rawdata_conds_ref = shift;
	my @rawdata_conds = @{$rawdata_conds_ref};
	my $tabdelimited_output = shift;
	my $output_dir = shift;
	my $ttest_pvalue_cutoff = shift;
	my $ttest_mean_cutoff = shift;
	my $adjpvalue = shift;
	my $adjpvalue_type = shift;

	my $pvalue_code = '';
	if ($adjpvalue) {
		$pvalue_code = 'p.value.adj';
	} elsif (!$adjpvalue) {
		$pvalue_code = 'p.value';
	}

	# Get unique labels for diff exp, create string to pass to R
	my %store_labels = ();
	for my $label (@rawdata_conds) {
		$store_labels{$label}++;
	}
	my @unique_labels = keys (%store_labels);
	@unique_labels = sort {$a <=> $b} @unique_labels;
	my $labels_string = '';
	for my $i (0..$#unique_labels) {
		$labels_string = $labels_string.'"'.$unique_labels[$i].'"';
		if ($i < $#unique_labels) {
			$labels_string = $labels_string.', ';
		}
	}
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Using unique conditions (".$labels_string.") for t-test.\n";
	}

	# Load libraries for generating heatmap into R
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Loading libraries and subroutines required for t-test and heatmap generation...\n";
	}
		$R->send ('# Load required packages
	library("Biobase"); # for eset
	library("genefilter"); # for rowttests
	library("gtools"); # for foldchange, foldchange2logratio
	library("pheatmap"); # for pheatmap

	base.means.and.fold.change <- function(x, feature_indices) {
		this.result <- matrix(NA, nrow = 1, ncol = 5);
		colnames(this.result) <- c("baseMean", "baseMeanA", "baseMeanB", "foldChange", "log2FoldChange");
		this.result[1] <- mean(x);
		this.result[2] <- mean(x[feature_indices[[1]]]);
		this.result[3] <- mean(x[feature_indices[[2]]]);
		this.result[4] <- foldchange(this.result[,3], this.result[,2]);
		this.result[5] <- foldchange2logratio(this.result[,4]);
		return(this.result)
	}');

	# Send the conditions to R
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Sending conditions (".join (',', @rawdata_conds).") for t-test...\n";
	}
	$R->send ('conds <- array(c('.join (',', @rawdata_conds).'), dim=c('.scalar (@rawdata_conds).'));');
	
	# Do t-test on normalized_data
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Perform two-sided t-test on normalized data...\n";
	}
	$R->send ('eset <- new("ExpressionSet", exprs=data.matrix(norm_rna));
	ttest <- rowttests(exprs(eset), factor(conds));
	# Map features to columns by indices
	features <- sort(unique(conds));
	feature_indices <- list();
	for (i in (1:length(features))) {
		feature_indices[[i]] <- which(conds == features[i]  %in% c(TRUE))
	}
	# Calculate mean, mean by feature, fold change, and log_2 ratio of fold change
	base.mean.and.fold.change <- apply(norm_rna, 1, base.means.and.fold.change, feature_indices = feature_indices);
	base.mean.and.fold.change <- t(base.mean.and.fold.change);
	colnames(base.mean.and.fold.change) <- c("baseMean", "baseMeanA", "baseMeanB", "foldChange", "log2FoldChange");
	# Store calculations into ttest data frame
	ttest <- cbind(ttest, base.mean.and.fold.change);
	# Calculate adjusted p-value
	ttest$p.value.adj <- p.adjust(ttest$p.value, method = "'.$adjpvalue_type.'");
	# Add id column, change rownames to numbers, reorder columns
	ttest$id <- rownames(ttest);
	rownames(ttest) <- 1:nrow(ttest);
	ttest <- ttest[,c(10,4:8,3,9,1:2)];
	sort.ttest <- ttest[order(ttest$'.$pvalue_code.'),]; # sort results by p-values');

	# Output t-test to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted t-test to tab delimited file...\n";
		}
		$R->send ('write.table(sort.ttest, file = "'.$output_dir.'sorted_ttest.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted t-test to csv file...\n";
		}
		$R->send ('write.csv(sort.ttest, file = "'.$output_dir.'sorted_ttest.csv");');
	}

	# Prepare for heatmap using cutoff values
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Prepare for heatmap by taking pval < ".$ttest_pvalue_cutoff."...\n";
	}
	$R->send ('pval_row_index <- which((ttest$'.$pvalue_code.' < '.$ttest_pvalue_cutoff.') %in% c(TRUE));
	filtered_norm_rna <- norm_rna[pval_row_index, ]; # get normalized data with '.$pvalue_code.' < '.$ttest_pvalue_cutoff.'
	mean_row_index <- which((rowMeans(filtered_norm_rna) > '.$ttest_mean_cutoff.') %in% c(TRUE));
	filtered_norm_rna <- filtered_norm_rna[mean_row_index, ]; # get normalized data with mean > '.$ttest_mean_cutoff);

	# Output heatmap filtered data to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered t-test to tab delimited file...\n";
		}
		$R->send ('write.table(filtered_norm_rna, file = "'.$output_dir.'heatmap.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered t-test to csv file...\n";
		}
		$R->send ('write.csv(filtered_norm_rna, file = "'.$output_dir.'heatmap.csv");');
	}

	return 1;
}

=head3 generateHeatmap

	NanoString::TTest->generateHeatmap ($R, $output_dir, $heatmap_colors, $heatmap_clustercols, $heatmap_key);

Takes a R session reference, the output directory, and the heatmap colors.

=cut

sub generateHeatmap {
	my $package = shift;
	my $R = shift;
	my $output_dir = shift;
	my $heatmap_colors = shift;
	my $heatmap_clustercols = shift;
	my $heatmap_key = shift;

	# Generate heatmap
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Generate heatmap and output to file...\n";
	}
	$R->send ('# Convert _ to whitespace
	col_names <- colnames(data.matrix(filtered_norm_rna));
	col_names <- gsub("(sample_number__)", " ", col_names);
	col_names <- gsub("_", " ", col_names);
	colnames(filtered_norm_rna) <- col_names;
	# Adjust the margins
	row_names <- rownames(data.matrix(filtered_norm_rna));
	max_char_row <- max(nchar(row_names));
	max_char_col <- max(nchar(col_names));
	# Adjust image size
	# size for plot + size for label margins + size for dendrogram in pixels + outer margins
	heatmap_height <- length(row_names) * 30 + max_char_col * 8 + 50 + 50;
	heatmap_width <- length(col_names) * 30 + max_char_row * 8 + 50 + 50 + 75; # add 75 for legend
	png("'.$output_dir.'heatmap.png", height = heatmap_height, width = heatmap_width, res = 72);
	pheatmap(data.matrix(filtered_norm_rna), '.$heatmap_clustercols.', '.$heatmap_key.', scale = "row", border_color = NA, cellwidth = 30, cellheight = 30, treeheight_row = 75, treeheight_col = 75, annotation_legend = FALSE, fontsize = 12, fontfamily = "mono", fontface = "plain", color = '.$heatmap_colors.');
	dev.off();');

	return 1;
}

=head1 AUTHOR

Chris Brumbaugh <cbrumbau@soe.ucsc.edu>

=cut

1;
