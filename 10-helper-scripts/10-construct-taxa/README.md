## taxaJson.dat generation script
The name is misleading - it is **not** JSON but actually Sereal-encoded, Zstd compressed Perl hash reference built up from NCBI taxonomy files.

### Quickstart

```
./01-construct-taxa.sh
```
 
This script will: 
* download the Taxonomy data from NCBI,
* uncompress it,
* calls 10-construct-taxa.pl to process it.  

The final output is the file: **taxaJson.dat**

### Code Highlights

*Download taxonomy data from NCBI*

```
# bash

wget http://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
tar zxvf taxdump.tar.gz

```

*Construct edges to child-nodes from taxonomy data*

```
# Perl

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
``` 

*Sereal encoding + Zstd compression of Perl hash-reference*

```
# Perl

use Sereal;
use Compress::Zstd qw(compress);

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

```

