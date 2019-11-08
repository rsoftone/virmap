#!/usr/bin/env perl
# 10-construct-taxa.pl
#
# Usage: 
#     ./10-construct-taxa.pl path/to/ncbi-taxonomy-dir
#
# See example driver script: 01-construct-taxa.sh
#
# Description: 
#     Perl script for converting NCBI Taxonomy data into the Sereal-encoded
#     + zstd compressed Perl hash reference needed by VirMAP

###########################################################################
#  Copyright 2019 University of New South Wales
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
# 
use strict;
use warnings;
use English '-no_match_vars';
use Sereal;
use Compress::Zstd qw(compress);
 
if ($#ARGV + 1 < 1) {
    print "\nUsage: 10-construct-taxa.pl /path/to/ncbi/taxdump\n";
    exit;
}
 
my $basePath = $ARGV[0];
my $outputFn = "taxaJson.dat";
 
my $children = {};
my $parents  = {};
my $ranks    = {};
my $names    = {};
 
 
sub loadNodes {
	my $filename = "$basePath/nodes.dmp";
	open( my $fh => $filename ) || die "Could not open $filename: $!";
	while ( my $line = <$fh> ) {
		my (
			$taxonomyID,                          $parentTaxonomyID,       $taxonomyRank,
			$emblCode,                            $divisionID,             $isInheritedDivision,
			$geneticCodeID,                       $isInheritedGeneticCode, $mitochondrialGeneticCodeID,
			$isInheritedMitochondrialGeneticCode, $isHiddenInGenbank,      $isSubtreeHidden,
			$comments
		) = split /\t\|\t/, $line;
 
		$parents->{$taxonomyID} .= $parentTaxonomyID;
		$ranks->{$taxonomyID}   .= $taxonomyRank;
		push @{ $children->{$parentTaxonomyID} }, $taxonomyID;
	}
 
	close $fh;
}
 
 
sub loadNames {
	my $namesFile = "$basePath/names.dmp";
	open( my $fh => $namesFile ) || die "Could not open $namesFile: $!";
	while ( my $line = <$fh> ) {
		my ( $taxId, $nameTxt, $uniqueName, $nameClass ) = split /\t\|[\t\n]/, $line;
 
		# might want to use uniqueName instead, when present
		if ( $nameClass eq "scientific name" ) {
			$names->{$taxId} = $nameTxt;
		}
	}
 
	close $fh;
}
 
loadNodes;
loadNames;
 
# construct the final hash of hashes to serealize
my %taxdbData = (
	children => $children,
	parents  => $parents,
	names    => $names,
	ranks    => $ranks,
);
 
# dump it to the file in $outputFn
my $encoder = Sereal::Encoder->new();
open my $fh, '>:raw', $outputFn or die;
print $fh compress( $encoder->encode( \%taxdbData ) );
close $fh;

