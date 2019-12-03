#!/usr/bin/env perl
use strict;
use English '-no_match_vars';
use Bio::SeqIO;

my $input_fn = shift;
my $genbFile = shift;

my $input_fh;
my $hhash;
my $nlookupval = "NONE";
my $plookupval = "NONE";

my $seqio_object;
my $loc;

my $genbank_version;
my $genbank_taxonomy_id;
my $genbank_accession;
my $genbank_version;
my $genbank_protein_id;
my $genbank_protein_translation;
my $genbank_protein_location;
my $genbank_protein_product;
my $genbank_protein_codonStart;
my $genbank_protein_pos;

my $delay_count   = 0;
my $delay_seconds = 0;

# print $input_fn , "\n";
open $input_fh, '<', $input_fn or die 'Could not open file: ', $OS_ERROR;
while ( my $line = <$input_fh> ) {
	chomp $line;
	last if !$line;
	my ( $accession, $version, $gi ) = split /,/, $line, 3;
	$hhash->{"$accession.$version"} = $gi;

	# print $hhash->{"$accession.$version"}, "\n";
	# sleep 1;
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
			eval { $nlookupval = $hhash->{"$genbank_accession.$genbank_version"}; };
			if ($@) {
				$nlookupval = "NOT FOUND";
			}
			eval { $plookupval = $hhash->{"$genbank_protein_id"}; };
			if ($@) {
				$plookupval = "NOT FOUND";
			}
			#
			# Print the protein entry to Fasta file here
			#
			print ">GI|GI:", $nlookupval, "|", $genbank_accession, ".", $genbank_version, "|", $genbank_protein_id,
			  "|GI:", $plookupval, "|", $genbank_protein_product, "|", $seq_object->desc, ";pos=",
			  $genbank_protein_location, ";codonStart=", $genbank_protein_codonStart, ";taxId=", $genbank_taxonomy_id,
			  "\n";
			print $genbank_protein_translation, "\n";
			print "\n";
		}
	}

	# eval {
	#     $lookupval = $hhash->{"$genbank_accession.$genbank_version"};
	# };
	# if( $@ ) {
	#     $lookupval = "NOT FOUND";
	# }

}

close $input_fh or die 'Could not close file: ', $OS_ERROR;