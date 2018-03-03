#!/usr/bin/perl
##
# NanoString_RCC.pm
# 
# Perl module to read in and process NanoString raw data.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 02/14/2011
##

package NanoString::RCC;

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
 
	NanoString::RCC - Reads in and processes NanoString raw data.

=head1 SYNOPSIS

	use NanoString::RCC;
	my $RCC = NanoString::RCC->new ($path_to_file);
	$RCC->getSection ("Lane Attributes");
	$RCC->getValue ("Lane Attributes", "FovCount");
	$RCC->getRawData ();
	$RCC->setRawData ( \@raw_data );
	$RCC->getFormattedData ();
	$RCC->mergeData ( \($RCC2, $RCC3, ...), \@sample_labels, $sample_name_prefix );
	$RCC->classifyData ();
	$RCC->getClassifications ();
	$RCC->getFilteredData ( \@formatted_data, \("CodeClass1", "CodeClass2", ...), $filter_type );

=head1 DESCRIPTION

This is an object-oriented library which reads in NanoString raw data.

=head2 Methods

=head3 new

	my $RCC = NanoString::RCC->new ( $path_to_file );

Instantiates an object which holds NanoString raw data. Returns a hash which
represents the structure of the RCC source.

=cut

sub new {
	my $package = shift;
	my $path = shift;
	open (rccfileRead, $path);
		#~ or die format_localtime()."ERROR: Please enter a valid filepath ($path), stopped";
		# or return 0;
	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Path is: $path\n";
	}
	# Read in file, store in hash containing hashes/arrays
	my $line = "";
	my $self = {};
	while ($line = <rccfileRead>) {
		$line =~ s/\r|\n//g;
		# Read in one section at a time
		if ($line =~ m/<(\w+)>/) {
			my $hash_key = $1;
			# Store has a hash if not count data, else store as array
			if ($hash_key ne "Code_Summary") {
				$line = <rccfileRead>;
				$line =~ s/\r|\n//g;
				until ($line =~ m/<\/$hash_key>/) {
					my @temp = split (/,/, $line);
					# Set $temp[1] if intialized, else set as blank string
					if ($temp[1]) {
						$self->{'raw_data'}{$hash_key}{$temp[0]} = $temp[1];
					} else {
						$self->{'raw_data'}{$hash_key}{$temp[0]} = '';
					}
					$line = <rccfileRead>;
					$line =~ s/\r|\n//g;
				}
			} else {
				my $array_index = 0;
				$line = <rccfileRead>;
				$line =~ s/\r|\n//g;
				until ($line =~ m/<\/$hash_key>/) {
					my @temp = split (/,/, $line);
					# Ignore lines starting with +++
					my $has_comment = 0;
					foreach my $value (@temp) {
						if ($value =~ /^\+\+\+/) {
							$has_comment = 1;
						}
					}
						if (!$has_comment) {
						for (my $i = 0; $i < scalar (@temp); $i++) {
							$self->{'raw_data'}{$hash_key}[$array_index][$i] = $temp[$i];
						}
						$array_index++;
					}
					$line = <rccfileRead>;
					$line =~ s/\r|\n//g;
				}
			}
		}
	}
	close (rccfileRead);

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Created new RCC object:\n";
		while (my ($key, $value) = each (%{$self->{'raw_data'}})) {
			print STDERR "Attribute: $key\n";
			if ($key eq "Code_Summary") {
				print STDERR "( ";
				my @value_1 = @{$self->{'raw_data'}{$key}};
				for my $i (0..$#value_1) {
					my @value_2 = @{$self->{'raw_data'}{$key}[$i]};
					for my $j (0..$#value_2) {
						if ($debug > 1) {
							print STDERR "$self->{'raw_data'}{$key}[$i][$j]";
							if ($j < $#value_2){
								# Print for all except last value
								print STDERR ", ";
							}
						} else {
							if ($i < $debug_verbosity) {
								print STDERR "$self->{'raw_data'}{$key}[$i][$j]";
								if ($j < $#value_2) {
									# Print for all except last value
									print STDERR ", ";
								}
							}
						}
					}
					if ($debug > 1) {
						if ($i < $#value_1) {
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
			} else {
				print STDERR "{ ";
				my $k = 0;
				my %attribute = %{$self->{'raw_data'}{$key}};
				while (my ($key_2, $value_2) = each (%{$self->{'raw_data'}{$key}})) {
					print STDERR "$key_2 => $value_2";
					if ($k < (scalar keys %attribute)-1) {
						# Print for all except last value
						print STDERR ", ";
					}
					$k++;
				}
				print STDERR " }\n";
			}
		}
	}

	bless ($self, $package);
	return $self;
}

=head3 getSection

	my $attribute_ref = $RCC->getSection ( "attribute" );

Retrieves a hash or array of given attribute containing assigned fields and
values. Attribute string is case sensitive. Returns reference to a hash for a
given attribute or an array in the case of the raw data for "Code Summary".

=cut

sub getSection {
	my $self = shift;
	my $section = shift;
	$section =~ s/\s/_/; # replace any white spaces with underscore

	if ($section ne "Code_Summary") {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Retrieving section $section as hash...\n";
		}
		return \%{$self->{'raw_data'}{$section}};
	} else {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Retrieving section $section as array...\n";
		}
		return \@{$self->{'raw_data'}{$section}};
	}
}

=head3 getValue

	my $value = $RCC->getValue ( "attribute", "field" );

Retrieves a value as a string given an attribute and field. Attribute and
field strings are case sensitive. Does not work for attribute that contains
the raw data ("Code_Summary"). Returns a string containing the value for the
given attribute and field combination.

=cut

sub getValue {
	my $self = shift;
	my $section = shift;
	my $key = shift;
	$section =~ s/\s/_/; # replace any white spaces with underscore

	if ($section ne "Code_Summary") {
		if ($debug > 0) {
			print STDERR format_localtime()."DEBUG: Retrieving value for $section, $key:\n";
			print STDERR "$self->{'raw_data'}{$section}{$key}\n";
		}
		return $self->{'raw_data'}{$section}{$key};
	} else {
		print STDERR format_localtime()."ERROR: Cannot print Code_Summary.\n";
		return 0;
	}
}

=head3 getRawData

	my $raw_data_ref = $RCC->getRawData ();

Retrieves an array containing raw data values. Returns reference to an array
of data as presented as a 2D matrix in the RCC source file.

=cut

# Assume raw data is stored in Code_Summary tags
sub getRawData {
	my $self = shift;

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Retrieving raw data:\n";
		print STDERR "( ";
		my @value_1 = @{$self->{'raw_data'}{'Code_Summary'}};
		for my $i (0..$#value_1) {
			my @value_2 = @{$self->{'raw_data'}{'Code_Summary'}[$i]};
			for my $j (0..$#value_2) {
				if ($debug > 1) {
					print STDERR "$self->{'raw_data'}{'Code_Summary'}[$i][$j]";
						if ($j < $#value_2){
							# Print for all except last value
							print STDERR ", ";
						}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$self->{'raw_data'}{'Code_Summary'}[$i][$j]";
						if ($j < $#value_2){
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#value_1) {
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

	return \@{$self->{'raw_data'}{'Code_Summary'}};
}

=head3 setRawData

	my $RCC = $RCC->setRawData ( $raw_data_array_ref );

Sets an array containing raw data values to the raw data in an RCC object.
Returns reference to a RCC object.

=cut

# Assume raw data is stored in Code_Summary tags
sub setRawData {
	my $self = shift;
	my $raw_data_array_ref = shift;
	my @raw_data_array = @{$raw_data_array_ref};
	my @old_data_array = @{$self->{'raw_data'}{'Code_Summary'}};

	for my $i (0..$#old_data_array) {
		my @row = $old_data_array[$i];
		for my $j (0..$#row) {
			$self->{'raw_data'}{'Code_Summary'}[$i][$j] = $raw_data_array[$i][$j];
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Setting raw data:\n";
		print STDERR "( ";
		my @value_1 = @{$self->{'raw_data'}{'Code_Summary'}};
		for my $i (0..$#value_1) {
			my @value_2 = @{$self->{'raw_data'}{'Code_Summary'}[$i]};
			for my $j (0..$#value_2) {
				if ($debug > 1) {
					print STDERR "$self->{'raw_data'}{'Code_Summary'}[$i][$j]";
						if ($j < $#value_2){
							# Print for all except last value
							print STDERR ", ";
						}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$self->{'raw_data'}{'Code_Summary'}[$i][$j]";
						if ($j < $#value_2){
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#value_1) {
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

	return $self;
}

=head3 getFormattedData

	my $formatted_data_ref = $RCC->getRawData ( $label );

Retrieves an array containing formatted data values. Formatted data is a
matrix of all count data with row and column labels in the first column and
first row, repectively. Returns reference to an array of data of formatted
data.

=cut

sub getFormattedData {
	my $self = shift;
	my $label = shift;
	my %gene_to_index = (); # hash of specific column headers to array indices
	my @formatted_data = (); # array of all raw data merged, columns ordered by file input order
	my $header = '';
	my $raw_data_ref = $self->getRawData ();
	my @raw_data = @{$raw_data_ref};
	# Enter gene name column label
	$formatted_data[0][0] = "Accession";
	# Use user supplied labels, else combine
	# Date+StagePosition+FovCount+LaneID for column name
	if ($label) {
		$formatted_data[0][1] = $label;
	} else {
		my $raw_data_date = $self->getValue ("Sample Attributes", "Date");
		my $raw_data_stageposition = $self->getValue ("Lane Attributes", "StagePosition");
		my $raw_data_fovcount = $self->getValue ("Lane Attributes", "FovCount");
		my $raw_data_laneid = $self->getValue ("Lane Attributes", "ID");
		$formatted_data[0][1] = "d".$raw_data_date."_sp".$raw_data_stageposition."_fc".$raw_data_fovcount."_li".$raw_data_laneid;
	}
	for my $j (0..$#raw_data) {
		if ($j == 0) {
			# Map headers to indices
			%gene_to_index = ();
			my @row_0 = @{$raw_data[$j]};
			for my $k (0..$#row_0) {
				my $header = $raw_data[$j][$k];
				if ( ($header eq "Name") || ($header eq "Count")) {
					$gene_to_index{$header} = $k;
				}
			}
			# If did not get all required columns, return false
			if (! (grep {$_ eq "Name"} (keys (%gene_to_index)))) {
				print STDERR format_localtime()."ERROR: Missing Name column.\n";
				return 0;
			} elsif (! (grep {$_ eq "Count"} (keys (%gene_to_index)))) {
				print STDERR format_localtime()."ERROR: Missing Count column.\n";
				return 0;
			}
		} elsif ($raw_data[$j][0] eq "Message") {
			# Skip messages
			next;
		} else {
			# Generate gene accession row labels
			my $tmp_name = $raw_data[$j][$gene_to_index{"Name"}];
			$tmp_name =~ s/\s*\(\+\+\+\s+See\s+Message\s+Below\)//g;
			$tmp_name =~ s/\s/_/g;
			$formatted_data[$j][0] = $tmp_name;
			$formatted_data[$j][1] = $raw_data[$j][$gene_to_index{"Count"}];
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Formatting data from RCC object:\n";
		print STDERR "( ";
		for my $i (0..$#formatted_data) {
			my @array_1 = @{$formatted_data[$i]};
			for my $j (0..$#array_1) {
				if ($debug > 1) {
					print STDERR "$formatted_data[$i][$j]";
					if ($j < $#array_1) {
						# Print for all except last value
						print STDERR ", ";
					}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$formatted_data[$i][$j]";
						if ($j < $#array_1) {
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#formatted_data-1) {
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

	return \@formatted_data;
}

=head3 mergeData

	my $merged_data_ref = $RCC->mergeData ( \@array_of_other_RCCs, $sample_labels_ref, $sample_name_prefix );

Constructs an array containing merged formatted data values. Formatted data
is a matrix of all count data with row and column labels in the first column
and first row, repectively. Returns a reference to the array of merged and
formatted data.

=cut

sub mergeData {
	my $self = shift;
	my $array_RCC_ref = shift;
	my @array_RCC = @{$array_RCC_ref};
	my $raw_data_labels_ref = shift;
	my @raw_data_labels = @{$raw_data_labels_ref};
	unshift (@array_RCC, $self);
	# Merge raw data individual samples into one data set
	# Must have Accession and Count to succeed
	my %gene_to_index = (); # hash of specific column headers to array indices
	my @formatted_mergeddata = (); # array of all raw data merged, columns ordered by file input order
	$formatted_mergeddata[0][0] = "Accession";
	my $header = '';
	for my $i (0..$#array_RCC) {
		my $raw_data_ref = $array_RCC[$i]->getRawData ();
		my @raw_data = @{$raw_data_ref};
		# Use user supplied labels, else combine
		# Date+StagePosition+FovCount+LaneID for column name
		if ($#raw_data_labels == $#array_RCC) {
			$formatted_mergeddata[0][$i+1] = $raw_data_labels[$i];
		} else {
			my $raw_data_date = $array_RCC[$i]->getValue ("Sample Attributes", "Date");
			my $raw_data_stageposition = $array_RCC[$i]->getValue ("Lane Attributes", "StagePosition");
			my $raw_data_fovcount = $array_RCC[$i]->getValue ("Lane Attributes", "FovCount");
			my $raw_data_laneid = $array_RCC[$i]->getValue ("Lane Attributes", "ID");
			$formatted_mergeddata[0][$i+1] = "d".$raw_data_date."_sp".$raw_data_stageposition."_fc".$raw_data_fovcount."_li".$raw_data_laneid;
		}
		for my $j (0..$#raw_data) {
			if ($j == 0) {
				# Map headers to indices
				%gene_to_index = ();
				my @row_0 = @{$raw_data[$j]};
				for my $k (0..$#row_0) {
					my $header = $raw_data[$j][$k];
					if ( ($header eq "Name") || ($header eq "Count")) {
						$gene_to_index{$header} = $k;
					}
				}
				# If did not get all required columns, return false
				if (! (grep {$_ eq "Name"} (keys (%gene_to_index)))) {
					print STDERR format_localtime()."ERROR: Missing Name column.\n";
					return 0;
				} elsif (! (grep {$_ eq "Count"} (keys (%gene_to_index)))) {
					print STDERR format_localtime()."ERROR: Missing Count column.\n";
					return 0;
				}
			} elsif ($raw_data[$j][0] eq "Message") {
				# Skip messages
				next;
			} else {
				if ($i == 0) {
					# If first sample, generate gene accession row labels
					my $tmp_name = $raw_data[$j][$gene_to_index{'Name'}];
					$tmp_name =~ s/\s*\(\+\+\+\s+See\s+Message\s+Below\)//g;
					$tmp_name =~ s/\s/_/g;
					$formatted_mergeddata[$j][0] = $tmp_name;
				}
				# Store count data
				$formatted_mergeddata[$j][$i+1] = $raw_data[$j][$gene_to_index{'Count'}];
			}
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Merging raw data from RCC objects:\n";
		print STDERR "( ";
		for my $i (0..$#formatted_mergeddata) {
			my @array_1 = @{$formatted_mergeddata[$i]};
			for my $j (0..$#array_1) {
				if ($debug > 1) {
					print STDERR "$formatted_mergeddata[$i][$j]";
					if ($j < $#array_1) {
						# Print for all except last value
						print STDERR ", ";
					}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$formatted_mergeddata[$i][$j]";
						if ($j < $#array_1) {
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#formatted_mergeddata-1) {
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

	return \@formatted_mergeddata;
}

=head3 classifyData

	$RCC = $RCC->classifyData ();

Constructs a hash containing mapping of CodeClass to an array of Accession
numbers for genes.

=cut

sub classifyData {
	my $self = shift;
	my $raw_data_ref = $self->getRawData ();
	my @raw_data = @{$raw_data_ref};
	my %gene_to_index = (); # hash of specific column headers to array indices
	for my $i (0..$#raw_data) {
		if ($i == 0) {
			# First row contains column headers
			# Map headers to indices
			# Must have CodeClass and Name to proceed
			my @row_0 = @{$raw_data[$i]};
			for my $j (0..$#row_0) {
				my $header = $row_0[$j];
				if ( ($header eq "CodeClass") || ($header eq "Name")) {
					$gene_to_index{$header} = $j;
				}
			}
			# If did not get all required columns, return false
			if (! (grep {$_ eq "Name"} (keys (%gene_to_index)))) {
				print STDERR format_localtime()."ERROR: Missing Name column.\n";
				return 0;
			} elsif (! (grep {$_ eq "CodeClass"} (keys (%gene_to_index)))) {
				print STDERR format_localtime()."ERROR: Missing CodeClass column.\n";
				return 0;
			}
		} elsif ($raw_data[$i][0] eq "Message") {
			# Skip any messages
			next;
		} else {
			my $tmp_name = $raw_data[$i][$gene_to_index{"Name"}];
			$tmp_name =~ s/\s*\(\+\+\+\s+See Message Below\)//g;
			$tmp_name =~ s/\s/_/g;
			if (defined $self->{'classifications'}{$raw_data[$i][$gene_to_index{"CodeClass"}]}) {
				# If class is in the classifications hash
				push (@{$self->{'classifications'}{$raw_data[$i][$gene_to_index{"CodeClass"}]}}, $tmp_name);
			} else {
				# If array not intialized, start array
				@{$self->{'classifications'}{$raw_data[$i][$gene_to_index{"CodeClass"}]}} = ($tmp_name);
			}
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Classifying raw data:\n";
		print STDERR "{ ";
		my $i = 0;
		my %classifications = %{$self->{'classifications'}};
		while (my ($key, $value) = each (%{$self->{'classifications'}})) {
			print STDERR "$key => ( ";
			my @class_array = @{$self->{'classifications'}{$key}};
			for my $j (0..$#class_array) {
				if ($debug > 1) {
					print STDERR "$class_array[$j]";
					if ($j < $#class_array) {
						print STDERR ", ";
					}
				} else {
					if ($j < $debug_verbosity) {
						print STDERR "$class_array[$j]";
						if ($j < $debug_verbosity-1) {
							print STDERR ", ";
						} else {
							print STDERR ", ..."
						}
					}
				}
			}
			print STDERR " )";
			if ($i < (scalar keys %classifications)-1) {
				print STDERR ", ";
			}
		}
		print STDERR " }\n";
	}

	return $self;
}

=head3 getClassifications

	my $classifications_ref = $RCC->getClassifications ();

Retrieves a reference to a hash of classifications that has been created and
formatted by classifyData ().

=cut

sub getClassifications {
	my $self = shift;

	if (defined $self->{'classifications'}) {
		return \%{$self->{'classifications'}};
	} else {
		$self = $self->classifyData ();
		return \%{$self->{'classifications'}};
	}
}

=head3 getFilteredData

	my $filtered_data_ref = $RCC->getFilteredData ( @merged_data,
		@list_of_classifications_to_filter, $filter_type );

Constructs an array containing filtered formatted data values, where filtered
classifcations specified are removed or kept as determined by filter type. The
filter type takes an integer: a non-zero (true) value keeps all
classifications provided in the classifications list, while a zero (false)
value removes the provided classifications in the classifications list.
Formatted data is a matrix of all count data with row and column labels in the
first column and first row, repectively. Returns a reference to the array of
filtered data.

=cut

sub getFilteredData {
	my $self = shift;
	my $formatted_data_ref = shift;
	my @formatted_data = @{$formatted_data_ref};
	my $filters_ref = shift;
	my @filters = @{$filters_ref};
	my $filter_type = shift;
	my $classifications_ref = $self->getClassifications ();
	my %classifications = %{$classifications_ref};
	# Generate array of accessions to filter
	my @accession_filters = ();
	foreach my $filter (@filters) {
		push (@accession_filters, @{$classifications{$filter}});
	}
	my $i_new = 0; # row index for new filtered array
	my @filtered_data = ();
	for my $i (0..$#formatted_data) {
		my @row = @{$formatted_data[$i]};
		if ($i == 0) {
			# Handle the first row of column headers in formatted data
			for my $j (0..$#row) {
				my $header = $row[$j]; 
				$filtered_data[$i][$j] = $header;
			}
		} else {
			for my $j (0..$#row) {
				my $column = $row[$j];
				if ($j == 0) {
					# Check for filtered classifications
					if ($filter_type) {
						if (! (grep {$_ eq $column} @accession_filters)) {
							last; # skip this row
						} else {
							$i_new++; # increment row counter
						}
					} else {
						if (grep {$_ eq $column} @accession_filters) {
							last; # skip this row
						} else {
							$i_new++; # increment row counter
						}
					}
				}
				$filtered_data[$i_new][$j] = $column;
			}
		}
	}

	if ($debug > 0) {
		print STDERR format_localtime()."DEBUG: Filtering ";
		if ($filter_type) {
			print STDERR "in";
		} else {
			print STDERR "out";
		}
		print STDERR " classification list (";
		for my $i (0..$#filters) {
			print STDERR $filters[$i];
			if ($i < $#filters) {
				print STDERR ", ";
			}
		}
		print STDERR ") from given data:\n";
		print STDERR "( ";
		for my $i (0..$#filtered_data) {
			my @array_1 = @{$filtered_data[$i]};
			for my $j (0..$#array_1) {
				if ($debug > 1) {
					print STDERR "$filtered_data[$i][$j]";
					if ($j < $#array_1) {
						# Print for all except last value
						print STDERR ", ";
					}
				} else {
					if ($i < $debug_verbosity) {
						print STDERR "$filtered_data[$i][$j]";
						if ($j < $#array_1) {
							# Print for all except last value
							print STDERR ", ";
						}
					}
				}
			}
			if ($debug > 1) {
				if ($i < $#filtered_data-1) {
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

	return \@filtered_data;
}

=head1 AUTHOR

Chris Brumbaugh <cbrumbau@soe.ucsc.edu>

=cut

1;
