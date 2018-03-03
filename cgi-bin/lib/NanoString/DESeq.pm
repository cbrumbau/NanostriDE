#!/usr/bin/perl
##
# NanoString/DESeq.pm
# 
# Perl module to perform normalization and negative binomial test for
# differential expression analysis and generates a heatmap.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 03/10/2011
##

package NanoString::DESeq;

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
 
	NanoString::DESeq - Normalizes NanoString data and generates a
	heatmap from this normalized data with DESeq.

=head1 SYNOPSIS

	use NanoString::DESeq;
	NanoString::DESeq->applyDESeq ($R, $raw_conds_ref, $tabdelimited_output, $output_dir, $DESeq_pvalue_cutoff, $DESeq_mean_cutoff, $pvalue, $adjpvalue_type);
	NanoString::DESeq->generateHeatmap ($R, $output_dir, $heatmap_options, $heatmap_colors, $heatmap_clustercols, $heatmap_key);

=head1 DESCRIPTION

This is a library which applies normalizations to NanoString data and
generates a heatmap.

=head2 Methods

=head3 applyNormalization

	NanoString::DESeq->applyDESeq ($R, $raw_conds_ref, $tabdelimited_output, $output_dir, $DESeq_pvalue_cutoff, $DESeq_mean_cutoff, $pvalue, $adjpvalue_type);

Takes a R session reference, the labels string to pass to R, a reference to an
array of condition labels for DESeq, a flag to designate tab delimited output,
the path to the output directory, the cutoff value for the p-value for the
heatmap, and the cutoff for the base mean counts for the heatmap. Normalizes
the data and performs the negative binomial test with DESeq.

=cut

sub applyDESeq {
	my $package = shift;
	my $R = shift;
	my $rawdata_conds_ref = shift;
	my @rawdata_conds = @{$rawdata_conds_ref};
	my $tabdelimited_output = shift;
	my $output_dir = shift;
	my $DESeq_pvalue_cutoff = shift;
	my $DESeq_mean_cutoff = shift;
	my $adjpvalue = shift;
	my $adjpvalue_type = shift;


	my $pvalue_code = '';
	if ($adjpvalue) {
		$pvalue_code = 'padj';
	} elsif (!$adjpvalue) {
		$pvalue_code = 'pval';
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
		print STDERR format_localtime()."DEBUG: Using unique conditions ($labels_string) for DESeq.\n";
	}

	# Load subroutines for generating heatmap into R
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Loading libraries and subroutines required for DESeq and heatmap generation...\n";
	}
	$R->send ('# Load required packages
	library("DESeq"); # for everything in difex & getnormdata
	library("gtools"); # for foldchange, foldchange2logratio
	library("pheatmap"); # for pheatmap

	# Perform diff exp analysis with DESeq, returns result
	# Given as sample code in DESeq documentation
	difex <- function(countsTable, conds) {
		cds <- newCountDataSet(countsTable, conds);
		cds <- estimateSizeFactors(cds);
		cds <- estimateVarianceFunctions(cds, locfit_extra_args=list(maxk=900)); # out of vertex points...?
		res <- nbinomTest(cds, '.$labels_string.');
		return(res);
	}

	# Perform diff exp analysis with DESeq, returns the data that has been
	# normalized through DESeq
	getnormdata <- function(countsTable, conds) {
		cds <- newCountDataSet(countsTable, conds);
		cds <- estimateSizeFactors(cds);
		cds <- estimateVarianceFunctions(cds, locfit_extra_args=list(maxk=900)); # out of vertex points...?
		vsd <- getVarianceStabilizedData(cds); # get normalized data
		return(vsd);
	}');

	# Put in for loop for multiple sets of conditions?
	# Put in switch for t-test vs. DESeq! and ANOVA?

	# Send the conditions to R
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Sending conditions (".join (',', @rawdata_conds).") for differential expression analysis...\n";
	}
	$R->send ('conds <- array(c('.join (',', @rawdata_conds).'), dim=c('.scalar (@rawdata_conds).'));');

	# Do diff exp on normalized_data
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Perform differential expression on normalized data...\n";
	}
	$R->send ('norm_rna <- round(norm_rna); # round the counts data
	diffexp <- difex(norm_rna, conds);
	# Calculate adjusted p-value
	diffexp$padj <- p.adjust(diffexp$pval, method = "'.$adjpvalue_type.'");
	sort.diffexp <- diffexp[ order(diffexp$'.$pvalue_code.'), ]; # sort results by p-values');

	# Output DESeq normalized to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing DESeq normalized to tab delimited file...\n";
		}
		$R->send ('write.table(getnormdata(norm_rna, conds), file = "'.$output_dir.'DESeq_normalized.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing DESeq normalized to csv file...\n";
		}
		$R->send ('write.csv(getnormdata(norm_rna, conds), file = "'.$output_dir.'DESeq_normalized.csv");');
	}

	# Output diff exp to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted DESeq to tab delimited file...\n";
		}
		$R->send ('write.table(sort.diffexp, file = "'.$output_dir.'sorted_DESeq.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted DESeq to csv file...\n";
		}
		$R->send ('write.csv(sort.diffexp, file = "'.$output_dir.'sorted_DESeq.csv");');
	}

	# Prepare for heatmap using cutoff values
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Prepare for heatmap by taking ".$pvalue_code." < ".$DESeq_pvalue_cutoff." and base mean > ".$DESeq_mean_cutoff."...\n";
	}
	$R->send ('genes <- diffexp[diffexp$'.$pvalue_code.' < '.$DESeq_pvalue_cutoff.', ]; # get subset of genes where '.$pvalue_code.' < '.$DESeq_pvalue_cutoff.'
	genes <- genes[genes$baseMean > '.$DESeq_mean_cutoff.', ]; # get subset of genes where baseMean > '.$DESeq_mean_cutoff.'
	genes <- na.omit(genes); # remove any NA values
	genes <- genes[,c("id")]; # get array of gene ids
	vsd <- getnormdata(norm_rna, conds); # get normalized data
	vsd <- vsd[genes, ]; # get normalized data with '.$pvalue_code.' < '.$DESeq_pvalue_cutoff.', baseMean > '.$DESeq_mean_cutoff);

	# Output heatmap filtered data to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered DESeq to tab delimited file...\n";
		}
		$R->send ('write.table(vsd, file = "'.$output_dir.'heatmap.tab", sep = "\t");');
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered DESeq to csv file...\n";
		}
		$R->send ('write.csv(vsd, file = "'.$output_dir.'heatmap.csv");');
	}

	return 1;
}

=head3 generateHeatmap

	NanoString::DESeq->generateHeatmap ($R, $output_dir, $heatmap_options, $heatmap_colors, $heatmap_clustercols, $heatmap_key);

Takes a R session reference, the output directory, the heatmap graphing
options, the heatmap colors, and the number of sample name labels used.

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
	col_names <- colnames(vsd);
	col_names <- gsub("(sample_number__)", " ", col_names);
	col_names <- gsub("_", " ", col_names);
	colnames(vsd) <- col_names;
	# Adjust the margins
	row_names <- rownames(vsd);
	max_char_row <- max(nchar(row_names));
	max_char_col <- max(nchar(col_names));
	# Adjust image size
	# size for plot + size for label margins + size for dendrogram in pixels + outer margins
	heatmap_height <- length(row_names) * 30 + max_char_col * 8 + 50 + 50;
	heatmap_width <- length(col_names) * 30 + max_char_row * 8 + 50 + 50 + 75; # add 75 for legend
	png("'.$output_dir.'heatmap.png", height = heatmap_height, width = heatmap_width, res = 72);
	pheatmap(vsd, '.$heatmap_clustercols.', '.$heatmap_key.', scale = "row", border_color = NA, cellwidth = 30, cellheight = 30, treeheight_row = 75, treeheight_col = 75, annotation_legend = FALSE, fontsize = 12, fontfamily = "mono", fontface = "plain", color = '.$heatmap_colors.');
	dev.off();');

	return 1;
}

=head1 AUTHOR

Chris Brumbaugh <cbrumbau@soe.ucsc.edu>

=cut

1;
