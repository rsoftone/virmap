#!/usr/bin/env perl
use strict;
use English '-no_match_vars';
use Boulder::Genbank;
use List::Util qw[min max];

my $input_fn = shift;
my $genbFile = shift;

my $input_fh;
my $lookupval = "NONE";

my $genbank_taxonomy_id;
my $genbank_accession;
my $genbank_version;

open $input_fh, '<', $input_fn or die 'Could not open file: ', $OS_ERROR;


sub next_accver {
	my $line = <$input_fh>;
	chomp $line;
	return undef if !$line;
	my ( $accession, $version, $gi ) = split /,/, $line, 3;
	return "$accession.$version", $gi;
}

# binary_seek will gradually increase skip_amount to a max of 50MiB when it
# undershoots the target accession, allowing skip_amount to be initially low
# as it's common for the accessions of interest to be relatively clustered.
sub binary_seek {
	my $target      = $_[0];
	my $init_pos    = $_[1];
	my $skip_amount = $_[2];

	# make the assumption that a skip_amount of < 5 is indicative of skipping
	# less than a line ==> i.e. can't be found
	return undef if ( $skip_amount < 5 );

	my $seek_pos = $init_pos + $skip_amount;
	seek $input_fh, $seek_pos, 0;
	readline $input_fh;    # jump to the start of a line

	my ( $accssession_ver, $gi ) = next_accver();

	if ( $accssession_ver gt $target ) {
		return binary_seek( $target, $init_pos, int( $skip_amount / 2 ) );
	}
	if ( $accssession_ver lt $target ) {
		return binary_seek( $target, $seek_pos, min( $skip_amount * 2, 52428800 ) );
	}
	return $gi if ( $accssession_ver eq $target );

	die "what?";
}

# simple driver around lookingup up gi from accession using binary_seek
sub find_gi {
	my $target = $_[0];

	my $pos = tell $input_fh;
	my ( $accssession_ver, $gi ) = next_accver();

	return undef if ( $accssession_ver gt $target );
	return $gi   if ( $accssession_ver eq $target );

	return binary_seek( $target, $pos, 512 );
}

my $gb = new Boulder::Genbank(
	-accessor => 'File',
	-fetch    => $genbFile
);


if ($@) {
	print " Error: $@ ";
	exit(-1);
}

while ( my $s = $gb->get ) {
	my $seq_object = $s->bioSeq;

	if ( $s->Features and $s->Features->Source and $s->Features->Source->Db_xref =~ m/taxon:(\d+)/ ) {
		$genbank_taxonomy_id = $1;
	}

	$genbank_accession = $s->Accession;
	$genbank_version   = $s->Version;

	$lookupval = find_gi("$genbank_version");

	# if (! defined($lookupval)) {
	if ($@) {
		$lookupval = "NOT FOUND";
	}
	print ">gi|", $lookupval, "|", "gb", "|", $genbank_version, "|", $seq_object->desc,
	  "...;taxId=", $genbank_taxonomy_id, "\n";

	print uc( $s->Sequence ), "\n";
	print "\n";
}

close $input_fh or die 'Could not close file: ', $OS_ERROR;
