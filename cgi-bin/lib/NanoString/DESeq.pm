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
our $script = '';
our $debug = 0;
our $debug_verbosity = 3;

sub setScript {
	my ($package, $file) = @_;
	$script = $file;
}

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

Takes the labels string to pass to R, a reference to an array of condition
labels for DESeq, a flag to designate tab delimited output, the path to the
output directory, the cutoff value for the p-value for the heatmap, and the
cutoff for the base mean counts for the heatmap. Normalizes the data and
performs the negative binomial test with DESeq.

=cut

sub applyDESeq {
	my $package = shift;
	my $rawdata_conds_ref = shift;
	my @rawdata_conds = @{$rawdata_conds_ref};
	my $tabdelimited_output = shift;
	my $output_dir = shift;
	my $DESeq_pvalue_cutoff = shift;
	my $DESeq_mean_cutoff = shift;
	my $adjpvalue = shift;
	my $adjpvalue_type = shift;

	open (RSCRIPT, '>>', $script);

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
	print RSCRIPT '# Load required packages
library("DESeq"); # for everything in difex & getnormdata
library("gtools"); # for foldchange, foldchange2logratio
library("pheatmap"); # for pheatmap

options(error=dump.frames, warn=2) # Allow execution after warnings

# Perform diff exp analysis with DESeq, returns result
# Given as sample code in DESeq documentation
difex <- function(countsTable, conds, replicates) {
	cds <- newCountDataSet(countsTable, conds);
	cds <- estimateSizeFactors(cds);
	if (length(unique(conds)) == length(conds)) {
		cds <- tryCatch(estimateDispersions(cds, method=c("blind"), sharingMode = c("fit-only"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("blind"), sharingMode = c("fit-only"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	} else if (min(replicates) <= 2) {
		cds <- tryCatch(estimateDispersions(cds, method=c("pooled"), sharingMode = c("fit-only"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("pooled"), sharingMode = c("fit-only"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	} else {
		cds <- tryCatch(estimateDispersions(cds, method=c("pooled"), sharingMode = c("maximum"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("pooled"), sharingMode = c("maximum"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	}
	res <- nbinomTest(cds, '.$labels_string.');
	return(res);
}

# Perform diff exp analysis with DESeq, returns the data that has been
# normalized through DESeq
getnormdata <- function(countsTable, conds, replicates) {
	cds <- newCountDataSet(countsTable, conds);
	cds <- estimateSizeFactors(cds);
	if (length(unique(conds)) == length(conds)) {
		cds <- tryCatch(estimateDispersions(cds, method=c("blind"), sharingMode = c("fit-only"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("blind"), sharingMode = c("fit-only"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	} else if (min(replicates) <= 2) {
		cds <- tryCatch(estimateDispersions(cds, method=c("pooled"), sharingMode = c("fit-only"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("pooled"), sharingMode = c("fit-only"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	} else {
		cds <- tryCatch(estimateDispersions(cds, method=c("pooled"), sharingMode = c("maximum"), locfit_extra_args=list(maxk=200)), error=function(e) e, warning=function(w) {cds <- estimateDispersions(cds, method=c("pooled"), sharingMode = c("maximum"), fitType = c("local"), locfit_extra_args=list(maxk=200));});
	}
	return(counts(cds,1));
}'."\n";

	# Send the conditions to R
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Sending conditions (".join (',', @rawdata_conds).") for differential expression analysis...\n";
	}
	print RSCRIPT 'conds <- array(c('.join (',', @rawdata_conds).'), dim=c('.scalar (@rawdata_conds).'));'."\n";

	# Do diff exp on normalized_data
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Perform differential expression on normalized data...\n";
	}
	print RSCRIPT '#norm_rna <- round(norm_rna); # round the counts data
norm_rna <- rna;
replicates <- table(as.factor(conds)); # table of replicates
diffexp <- difex(norm_rna, conds, replicates);
# Calculate adjusted p-value
diffexp$padj <- p.adjust(diffexp$pval, method = "'.$adjpvalue_type.'");
sort.diffexp <- diffexp[ order(diffexp$'.$pvalue_code.'), ]; # sort results by p-values'."\n";

	# Output DESeq normalized to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing DESeq normalized to tab delimited file...\n";
		}
		print RSCRIPT 'write.table(getnormdata(norm_rna, conds, replicates), file = "'.$output_dir.'DESeq_normalized.tab", sep = "\t");'."\n";
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing DESeq normalized to csv file...\n";
		}
		print RSCRIPT 'write.csv(getnormdata(norm_rna, conds, replicates), file = "'.$output_dir.'DESeq_normalized.csv");'."\n";
	}

	# Output diff exp to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted DESeq to tab delimited file...\n";
		}
		print RSCRIPT 'write.table(sort.diffexp, file = "'.$output_dir.'sorted_DESeq.tab", sep = "\t");'."\n";
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing sorted DESeq to csv file...\n";
		}
		print RSCRIPT 'write.csv(sort.diffexp, file = "'.$output_dir.'sorted_DESeq.csv");'."\n";
	}

	# Prepare for heatmap using cutoff values
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Prepare for heatmap by taking ".$pvalue_code." < ".$DESeq_pvalue_cutoff." and base mean > ".$DESeq_mean_cutoff."...\n";
	}
	print RSCRIPT 'genes <- diffexp[diffexp$'.$pvalue_code.' < '.$DESeq_pvalue_cutoff.', ]; # get subset of genes where '.$pvalue_code.' < '.$DESeq_pvalue_cutoff.'
genes <- genes[genes$baseMean > '.$DESeq_mean_cutoff.', ]; # get subset of genes where baseMean > '.$DESeq_mean_cutoff.'
genes <- na.omit(genes); # remove any NA values
genes <- genes[,c("id")]; # get array of gene ids
vsd <- getnormdata(norm_rna, conds, replicates); # get normalized data
vsd <- vsd[genes, ]; # get normalized data with '.$pvalue_code.' < '.$DESeq_pvalue_cutoff.', baseMean > '.$DESeq_mean_cutoff."\n";

	# Output heatmap filtered data to file
	if ($tabdelimited_output) {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered DESeq to tab delimited file...\n";
		}
		print RSCRIPT 'write.table(vsd, file = "'.$output_dir.'heatmap.tab", sep = "\t");'."\n";
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Writing filtered DESeq to csv file...\n";
		}
		print RSCRIPT 'write.csv(vsd, file = "'.$output_dir.'heatmap.csv");'."\n";
	}

	close (RSCRIPT);

	return 1;
}

=head3 generateHeatmap

	NanoString::DESeq->generateHeatmap ($R, $output_dir, $heatmap_options, $heatmap_colors, $heatmap_clustercols, $heatmap_key);

Takes the output directory, the heatmap graphing options, the heatmap colors,
and the number of sample name labels used.

=cut

sub generateHeatmap {
	my $package = shift;
	my $output_dir = shift;
	my $heatmap_colors = shift;
	my $heatmap_clustercols = shift;
	my $heatmap_key = shift;
	my $warnings_file = shift;

	open (RSCRIPT, '>>', $script);

	# Check if heatmap can be generated, else provide warning
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Processing warnings type 6...\n";
	}
	# 6. No statistically significant probes identified, heatmap cannot be generated
	print RSCRIPT '# 6. No statistically significant probes identified, heatmap cannot be generated
warnings <- c();
if (nrow(vsd) == 0) {
	warnings <- append(warnings, paste("WARNING: No statistically significant probes identified, heatmap cannot be generated."));
}
if (nrow(vsd) == 1) {
	warnings <- append(warnings, paste("WARNING: One statistically significant probe identified, heatmap cannot be generated."));
}
if (!exists("vsd")) {
	warnings <- append(warnings, paste("WARNING: No statistically significant probes identified, heatmap cannot be generated. (Running DESeq failed.)"));
}
if (length(warnings) > 0) {
	FILEWRITE <- file("'.$warnings_file.'", open = "a");
	writeLines(warnings, FILEWRITE);
	close(FILEWRITE);
}'."\n";

	# Generate heatmap
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Generate heatmap and output to file...\n";
	}
	print RSCRIPT '# Load Cairo package
library("Cairo");

if (nrow(vsd) > 1) {
	# Convert _ to whitespace
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
	CairoPNG(filename = "'.$output_dir.'heatmap.png", height = heatmap_height, width = heatmap_width, res = 72);
	pheatmap(vsd, '.$heatmap_clustercols.', '.$heatmap_key.', scale = "row", border_color = NA, cellwidth = 30, cellheight = 30, treeheight_row = 75, treeheight_col = 75, annotation_legend = FALSE, fontsize = 12, fontfamily = "mono", fontface = "plain", color = '.$heatmap_colors.');
	dev.off();
}'."\n";

	close (RSCRIPT);

	return 1;
}

=head1 AUTHOR

Chris Brumbaugh <cbrumbau@soe.ucsc.edu>

=cut

1;
