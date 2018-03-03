#!/usr/bin/perl
##
# NanoString/Corrections.pm
# 
# Perl module to perform corrections on NanoString miRNA raw data.
# Corrections are hard coded into the module, use the globals
# in the module to update it with newer correction data.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 03/02/2011
##

package NanoString::Corrections;

use strict;
use warnings;

our $VERSION = 1.0;
our $debug = 0;
our $debug_verbosity = 3;

# Set hardcoded correction values
our %human = (
	'hsa-let-7e' => 0.011,
	'hsa-miR-16' => 0.087,
	'hsa-miR-20a+hsa-miR-20b' => 0.043,
	'hsa-miR-26a' => 0.051,
	'hsa-miR-27b' => 0.426,
	'hsa-miR-32' => 0.007,
	'hsa-miR-34b' => 0.010,
	'hsa-miR-125a-3p' => 0.018,
	'hsa-miR-132' => 0.014,
	'hsa-miR-181a' => 0.008,
	'hsa-miR-188-5p' => 0.015,
	'hsa-miR-192' => 0.020,
	'hsa-miR-193a-3p' => 0.008,
	'hsa-miR-196a' => 0.009,
	'hsa-miR-206' => 0.008,
	'hsa-miR-223' => 0.010,
	'hsa-miR-320c' => 0.291,
	'hsa-miR-453' => 0.010,
	'hsa-miR-485-3p' => 0.084,
	'hsa-miR-494' => 0.087,
	'hsa-miR-518f' => 0.016,
	'hsa-miR-520d-5p+hsa-miR-527+ hsa-miR-518a-5p' => 0.012,
	'hsa-miR-520e' => 0.008,
	'hsa-miR-539' => 0.016,
	'hsa-miR-544' => 0.648,
	'hsa-miR-548a-5p' => 0.008,
	'hsa-miR-561' => 0.009,
	'hsa-miR-563' => 0.011,
	'hsa-miR-579' => 0.078,
	'hsa-miR-590-5p' => 0.138,
	'hsa-miR-664' => 0.020,
	'hsa-miR-708' => 0.009,
	'hsa-miR-720' => 0.010,
	'hsa-miR-744' => 0.078,
	'hsa-miR-1246' => 0.013,
	'hsa-miR-1283' => 0.020
	);

our %mouse = (
	'mmu-let-7f' => 100,
	'mmu-miR-142-5p' => 200
	);

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
 
	NanoString::Corrections - Processes NanoString raw miRNA data and applies corrections.

=head1 SYNOPSIS

	use NanoString::Corrections;
	my $corrected_data_ref = NanoString::Corrections->applyCorrections ($raw_data_array_ref, $correction_hash_ref, $type_of_correction, $actual_fov);

=head1 DESCRIPTION

This is a library which applies corrections to NanoString raw data.

=head2 Methods

=head3 new

	NanoString::Corrections->applyCorrections ($raw_data_array_ref, $correction_hash_ref, $type_of_correction, $actual_fov);

Takes a reference to a raw data array from an RCC object (use getRawData())
and the type of correction to apply. Returns a reference to an array that
contains the corrected raw data. It is recommended to store the corrected data
in the RCC object that the raw data was taken from (use setRawData()).

=cut

sub applyCorrections {
	my $package = shift;
	my $raw_data_array_ref = shift;
	my @raw_data_array = @{$raw_data_array_ref};
	my $corrections_hash_ref = shift;
	my %corrections_hash = %{$corrections_hash_ref};
	my $type_of_correction = shift;
	my $actual_fov = shift;
	my %gene_to_index = ();
	my @corrected_data_array = @raw_data_array; # only change values in need of correction
	my $POS_128fM = 0;
	my $j = 0;
	for my $i (0..$#raw_data_array) {
		if ($i == 0) {
			# Map headers to indices
			my @row_0 = @{$raw_data_array[$i]};
			for my $j (0..$#row_0) {
				my $header = $raw_data_array[$i][$j];
				$gene_to_index{$header} = $j;
			}
		} else {
			# Handle all the rows
			my @row = @{$raw_data_array[$i]};
			if ($type_of_correction eq "human") {
				if ($row[$gene_to_index{"Name"}] =~ m/POS_A\(128\)/) {
					$POS_128fM = $row[$gene_to_index{"Count"}];
					if ($debug > 0) {
						print STDERR format_localtime()."DEBUG: Count of 128fM is $POS_128fM\n";
					}
				}
				if (scalar (keys (%corrections_hash)) > 0) {
					# New format
					my $name = $row[$gene_to_index{"Name"}];
					if (exists $corrections_hash{$name}) {
						my $count = $raw_data_array[$i][$gene_to_index{"Count"}]-($POS_128fM*$corrections_hash{$name});
						if ($debug > 0) {
							print STDERR format_localtime()."DEBUG: Corrected value for $name is ".$raw_data_array[$i][$gene_to_index{"Count"}]." - ($POS_128fM * ".$corrections_hash{$name}." = $count\n";
						}
						if ($count > 0) {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = $count;
						} else {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = 0;
						}
					}
				} elsif ($row[$gene_to_index{"Name"}] =~ m/.+\(\+\+\+\s+See\s+Message\s+Below\)/) {
					# Old format
					my $name = $row[$gene_to_index{"Name"}];
					$name =~ s/\s*\(\+\+\+\s+See\s+Message\s+Below\)//g;
					$name =~ s/\s+//g; # strip whitespaces
					if (exists $human{$name}) {
						my $count = $raw_data_array[$i][$gene_to_index{"Count"}]-($POS_128fM*$human{$name});
						if ($debug > 0) {
							print STDERR format_localtime()."DEBUG: Corrected value for $name is ".$raw_data_array[$i][$gene_to_index{"Count"}]." - ($POS_128fM * ".$human{$name}." = $count\n";
						}
						if ($count > 0) {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = $count;
						} else {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = 0;
						}
					}
				}
			} elsif ($type_of_correction eq "mouse") {
				if (scalar (keys (%corrections_hash)) > 0) {
					# New format
					my $name = $row[$gene_to_index{"Name"}];
					if (exists $corrections_hash{$name}) {
						my $count = $raw_data_array[$i][$gene_to_index{"Count"}]-$corrections_hash{$name}*($actual_fov/600);
						if ($debug > 0) {
							print STDERR format_localtime()."DEBUG: Corrected value for $name is ".$raw_data_array[$i][$gene_to_index{"Count"}]." - ".$corrections_hash{$name}." * ($actual_fov / 600) = $count\n";
						}
						if ($count > 0) {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = $count;
						} else {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = 0;
						}
					}
				} elsif ($row[$gene_to_index{"Name"}] =~ m/.+\(\+\+\+\s+See\s+Message\s+Below\)/) {
					# Old format
					my $name = $row[$gene_to_index{"Name"}];
					$name =~ s/\s*\(\+\+\+\s+See\s+Message\s+Below\)//g;
					$name =~ s/\s+//g; # strip whitespaces
					if (exists $mouse{$name}) {
						my $count = $raw_data_array[$i][$gene_to_index{"Count"}]-$mouse{$name}*($actual_fov/600);
						if ($debug > 0) {
							print STDERR format_localtime()."DEBUG: Corrected value for $name is ".$raw_data_array[$i][$gene_to_index{"Count"}]." - ".$mouse{$name}." * ($actual_fov / 600) = $count\n";
						}
						if ($count > 0) {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = $count;
						} else {
							$corrected_data_array[$i][$gene_to_index{"Count"}] = 0;
						}
					}
				}
			}
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Corrected miRNA raw data:\n";
		print STDERR "( ";
		for my $i (0..$#corrected_data_array) {
			my @row = @{$corrected_data_array[$i]};
			for my $j (0..$#row) {
				if ($debug > 1) {
					print STDERR "$corrected_data_array[$i][$j]";
						if ($j < $#row){
							# Print for all except last value
							print STDERR ", ";
						}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$corrected_data_array[$i][$j]";
						if ($j < $#row){
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#corrected_data_array) {
					# Print for all except last value
					print STDERR "; ";
				}
			} else {
				if ($i < $debug_verbosity) {
					if ($i < $debug_verbosity-1) {
						# Print for all except last value
						print STDERR "; ";
					} else {
						print STDERR "; ...";
					}
				}
			}
		}
		print STDERR " )\n";
	}

	return \@corrected_data_array;
}

=head1 AUTHOR

Chris Brumbaugh <cbrumbau@soe.ucsc.edu>

=cut

1;
