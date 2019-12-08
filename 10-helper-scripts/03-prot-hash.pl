#!/usr/bin/env perl
use strict;
use English '-no_match_vars';
use List::Util qw[min max];
use Bio::SeqIO;

my $input_fn = shift;
my $genbFile = shift;

my $input_fh;
my $nlookupval = "NONE";
my $plookupval = "NONE";

my $seqio_object;
my $loc;

my $header;
my $genbank_version;
my $genbank_taxonomy_id;
my $genbank_accession;
my $genbank_protein_id;
my $genbank_protein_translation;
my $genbank_protein_location;
my $genbank_protein_product;
my $genbank_protein_codonStart;
my $genbank_protein_pos;

open $input_fh, '<', $input_fn or die 'Could not open file: ', $OS_ERROR;


sub next_accver {
	my $line = <$input_fh>;
	chomp $line;
	return undef if !$line;
	my ( $accession, $version, $gi ) = split /,/, $line, 3;
	return "$accession.$version", $gi;
}

# binary_seek will gradually increase skip_amount to a max of 1GiB when it
# undershoots the target accession, allowing skip_amount to be initially low
# as it's common for the accessions of interest to be relatively clustered.
sub binary_seek {
	my $target      = $_[0];
	my $init_pos    = $_[1];
	my $skip_amount = $_[2];

	if ( $skip_amount < 2 ) {
		seek $input_fh, $init_pos, 0;
		return undef;
	}

	my $seek_pos = $init_pos + $skip_amount;
	seek $input_fh, $seek_pos, 0;
	readline $input_fh;    # jump to the start of a line

	my ( $accssession_ver, $gi ) = next_accver();

	if ( $accssession_ver gt $target or !defined $accssession_ver ) {
		return binary_seek( $target, $init_pos, int( $skip_amount / 2 ) );
	}
	if ( $accssession_ver lt $target ) {
		return binary_seek( $target, $seek_pos, min( $skip_amount * 2, 1073741824 ) );
	}
	return $gi if ( $accssession_ver eq $target );

	die "what?";
}

# simple driver around lookingup up gi from accession using binary_seek
sub find_gi {
	my $target = $_[0];

	my $pos = tell $input_fh;
	my ( $accssession_ver, $gi ) = next_accver();

	if ( $accssession_ver gt $target ) {
		seek $input_fh, $pos, 0;
		return undef;
	}
	return $gi if ( $accssession_ver eq $target );

	return binary_seek( $target, $pos, 536870912 );
}

eval { $seqio_object = Bio::SeqIO->new( -file => $genbFile, -format => 'Genbank' ); };

if ($@) {
	print " Error: $@ ";
	exit(-1);
}

while ( my $seq_object = $seqio_object->next_seq() ) {
	$genbank_accession = $seq_object->accession;
	$genbank_version   = $seq_object->seq_version;
	for my $feat_object ( $seq_object->get_SeqFeatures ) {
		if ( $feat_object->primary_tag eq 'source' ) {
			for my $tag ( $feat_object->get_all_tags ) {
				if ( $tag eq 'db_xref' ) {
					for my $value ( $feat_object->get_tag_values($tag) ) {
						if ( $value =~ m/taxon:(\d+)/ ) {
							$genbank_taxonomy_id = $1;
						}
					}
				}
			}
		}
		if ( $feat_object->primary_tag eq 'CDS' ) {
			#
			# Extract Locations
			#
			if ( $feat_object->location->isa('Bio::Location::SplitLocationI') ) {
				my $sublocs = "";
				foreach $loc ( $feat_object->location->sub_Location ) {
					if ( $loc->strand eq '1' ) {
						$sublocs .=
						  $loc->start_pos_type . ":" . $loc->start . ".." . $loc->end_pos_type . ":" . $loc->end . " ,";
					} else {
						$sublocs .=
						  $loc->end_pos_type . ":" . $loc->end . ".." . $loc->start_pos_type . ":" . $loc->start . " ,";
					}
				}
				if ( $sublocs =~ m/(.*),$/ ) {
					$genbank_protein_location = $1;
				} else {
					$genbank_protein_location = "UNKNOWN-SPLIT";
				}
			} else {
				$genbank_protein_location = $feat_object->location->start . ".." . $feat_object->location->end;
			}
			#
			# Extract Features
			#
			for my $tag ( $feat_object->get_all_tags ) {

				# print "...", $tag, ":";
				if ( $tag eq 'protein_id' ) {
					for my $tvalue ( $feat_object->get_tag_values($tag) ) {
						$genbank_protein_id = $tvalue;
					}

					# print $genbank_protein_id, "\n";
				}
				if ( $tag eq 'translation' ) {
					for my $tvalue ( $feat_object->get_tag_values($tag) ) {
						$genbank_protein_translation = $tvalue;
					}

					# print $genbank_protein_translation, "\n";
				}
				if ( $tag eq 'product' ) {
					for my $tvalue ( $feat_object->get_tag_values($tag) ) {
						$genbank_protein_product = $tvalue;
					}

					# print $genbank_protein_product, "\n";
				}
				if ( $tag eq 'codon_start' ) {
					for my $tvalue ( $feat_object->get_tag_values($tag) ) {
						$genbank_protein_codonStart = $tvalue;
					}

					# print $genbank_protein_codonStart, "\n";
				}
			}

			seek $input_fh, 0, 0;    #  search the entire map file
			$nlookupval = find_gi("$genbank_accession.$genbank_version");
			if ($@) {
				$nlookupval = "NOT FOUND";
			}
			seek $input_fh, 0, 0;    #  search the entire map file
			$plookupval = find_gi("$genbank_protein_id");
			if ($@) {
				$plookupval = "NOT FOUND";
			}
			#
			# Print the protein entry to Fasta file here
			#
			$header =
">GI|GI:$nlookupval|$genbank_accession.$genbank_version|$genbank_protein_id|GI:$plookupval|$genbank_protein_product|"
			  . $seq_object->desc
			  . ";pos=$genbank_protein_location;codonStart=$genbank_protein_codonStart;taxId=$genbank_taxonomy_id\n";
			$header =~ tr/ /./;
			print $header;
			print $genbank_protein_translation, "\n";
			print "\n";
		}
	}
}

close $input_fh or die 'Could not close file: ', $OS_ERROR;