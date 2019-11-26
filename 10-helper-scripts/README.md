## Quicklinks
* [Taxonomy database](#part-1-taxonomy-database-generation)
* [Accession -> GI lookup](#part-2-accession---gi-lookup)
* [Genbank downloads](#part-3-genbank-division-download)
* [Nucleotide .fasta generation](#part-4-nucleotide-fasta-generation-using-katana-pbs-script)
* [Protein .fasta generation](#part-5-protein-fasta-generation-using-katana-pbs-script)
* [Build BBmap virus database](#part-6-build-bbmap-virus-database)
* [Build Diamond virus database](#part-7-build-diamond-virus-database)
* [Build Kraken2 database](#part-8-build-kraken2-database)


### Part 1: Taxonomy database generation
**Code files:**
- 10-construct-taxa/10-construct-taxa.pl

**Usage:**
```
cd 10-construct-taxa
./01-construct-taxa.sh
cd ..
```

### Part 2: Accession -> GI lookup
```
#!/bin/bash
GBACCLIST=GbAccList.0602.2019
wget https://ftp.ncbi.nih.gov/genbank/livelists/${GBACCLIST}.gz
gunzip ${GBACCLIST}.gz

# 
# Format:
# GENBANK-ACCESSION-NUMBER,SEQUENCE-VERSION,GI

# zcat GbAccList.0602.2019.gz | head -3
#
# AACY024124353,1,129566152
# AACY024124495,1,129566175
# AACY024124494,1,129566176
#
# Concatenate GENBANK-ACCESSION-NUMBER with SEQUENCE-VERSION to get the full accession e.g. "AACY024124353.1". 
# Uncompress and split this into parts, each with 64 million entries.  This allows us to use smaller sections  if we know which sections specifically we need.
#
# (Optional) Split the main file into parts, each with 64 million entries.
# This allows us to use smaller sections provided we know which sections specifically we need.
#

split -d -l 64000000 ${GBACCLIST} part
```

### Part 3: Genbank division download
```
#
# Assumes you have run the script in the previous section Part 2: Accession -> GI lookup
#
# This section uses the Aspera utility - see: https://downloads.asperasoft.com/connect2/
#
# Now download the Genbank division you want to the $GENBANKPATH directory (eg gbvrl):
#
 
export GENBANKPATH=genbank-ref
mkdir -p $GENBANKPATH

#
# Retrieve the list in ftp://ftp.ncbi.nlm.nih.gov/genbank
# 

wget --no-remove-listing ftp://ftp.ncbi.nlm.nih.gov/genbank

# See the resultant file named .listing

grep gbvrl .listing | sed 's/.*gbvrl/gbvrl/g' | sed 's/\n//g' > gbvrl.txt
dos2unix gbvrl.txt

while  read -r aseq
do
    ~/.aspera/connect/bin/ascp \
    -i ~/.aspera/connect/etc/asperaweb_id_dsa.openssh \
    -k1 -Tr -l800m \
    anonftp@ftp.ncbi.nlm.nih.gov:/genbank/${aseq} ${GENBANKPATH}/.  

done < gbvrl.txt

cd ${GENBANKPATH} && find -type f -exec gunzip \{\} \;
cd ..

export PREFIXDB=gbvrl
```
### Part 4: Nucleotide .fasta generation using Katana PBS script
05-genbank-fasta-nucleo.sh
```
#!/bin/bash
#PBS -l nodes=1:ppn=2
#PBS -l mem=250gb
#PBS -l walltime=03:00:00
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -N "${PREFIXDB}"-protein -J 1-$(find "${GENBANKPATH}" -type f -name "${PREFIXDB}"*.seq|wc -l) -v PREFIXDB="${PREFIXDB}" 05-genbank-fasta-nucleo.sh 
##
## Output directory for .fasta file: converted/nucleotide
##
cd "${PBS_O_WORKDIR}"

cd "${PBS_O_WORKDIR}"

PREFPATH=converted/nucleotide
GENBANKPATH=genbank-ref
TMPW=$(mktemp -d)

GBIN=$(find $GENBANKPATH -type f -name "${PREFIXDB}*.seq"|sort -n|sed -n "${PBS_ARRAY_INDEX}p")
SEQOUT=$(echo $GBIN|sed "s=$GENBANKPATH=$PREFPATH=g"|sed "s=.seq$=.fasta=g")

echo "${PBS_ARRAY_INDEX}":...GenBank Division: $PREFIXDB
echo "${PBS_ARRAY_INDEX}":...Input GenBank flat-file: $GBIN
echo "${PBS_ARRAY_INDEX}":...Output FASTA: $SEQOUT

time ./03-hash.pl <(cat part00 part01 part02 part03 part04 part05 part06 part07 part08 part09 part10 part11 part12 part13 part14 part15 part16 part17) "${GBIN}" > "${TMPW}/${PBS_ARRAY_INDEX}.fasta"

#
# Now copy results from TMP directory to final output location...
#

cp "${TMPW}/${PBS_ARRAY_INDEX}.fasta" "${SEQOUT}"
rm -rf "${TMPW}"
```
03-hash.pl
```
#!/usr/bin/env perl
use strict;
use English '-no_match_vars';
use Bio::SeqIO;

my $input_fn = shift;
my $genbFile = shift;

my $input_fh;
my $hhash;
my $lookupval = "NONE";

my $seqio_object;

my $genbank_version;
my $genbank_taxonomy_id;
my $genbank_accession;
my $genbank_version;

my $delay_count = 0;
my $delay_seconds = 0;

# print $input_fn , "\n";
open $input_fh, '<', $input_fn or die 'Could not open file: ', $OS_ERROR;
while ( my $line = <$input_fh> ) {
    chomp $line;
    last if ! $line;
    my ($accession,$version,$gi) = split /,/, $line, 3;
    $hhash->{"$accession.$version"} = $gi;
    # print $hhash->{"$accession.$version"}, "\n";
    # sleep 1;
}

eval {
    $seqio_object = Bio::SeqIO->new( -file => $genbFile
                                   , -format => 'Genbank'
                                   );
};

if( $@ ) {
    print " Error: $@ ";
    exit(-1);
}

while ( my $seq_object= $seqio_object->next_seq()) {
    for my $feat_object ($seq_object->get_SeqFeatures) {
        for my $tag ($feat_object->get_all_tags) {
            for my $value ($feat_object->get_tag_values($tag)) {
                if ($value =~ m/taxon:(\d+)/) {
                    $genbank_taxonomy_id = $1;
                }
            }
        }
    }
    $genbank_accession = $seq_object->accession;
    $genbank_version   = $seq_object->seq_version;
    eval {
        $lookupval = $hhash->{"$genbank_accession.$genbank_version"};
    };
    if( $@ ) {
        $lookupval = "NOT FOUND";
    }
    print ">gi|", $lookupval, "|", "gb", "|", $genbank_accession, ".", $genbank_version, "|", $seq_object->desc, "...;taxId=", $genbank_taxonomy_id, "\n";
    print $seq_object->seq, "\n";
    print "\n";
}

close $input_fh or die 'Could not close file: ', $OS_ERROR;
```
### Part 5: Protein .fasta generation using Katana PBS script
05-genbank-fasta-protein.sh 
```
#!/bin/bash
#PBS -l nodes=1:ppn=2
#PBS -l mem=250gb
#PBS -l walltime=03:00:00
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -N "${PREFIXDB}"-protein -J 1-$(find "${GENBANKPATH}" -type f -name "${PREFIXDB}"*.seq|wc -l) -v PREFIXDB="${PREFIXDB}" 05-genbank-fasta-protein.sh 
##
## Output directory for .fasta file: converted/protein
##
cd "${PBS_O_WORKDIR}"

PREFPATH=converted/protein
GENBANKPATH=genbank-ref
TMPW=$(mktemp -d)

GBIN=$(find $GENBANKPATH -type f -name "${PREFIXDB}*.seq"|sort -n|sed -n "${PBS_ARRAY_INDEX}p")
SEQOUT=$(echo $GBIN|sed "s=$GENBANKPATH=$PREFPATH=g"|sed "s=.seq$=.fasta=g")

echo "${PBS_ARRAY_INDEX}":...GenBank Division: $PREFIXDB
echo "${PBS_ARRAY_INDEX}":...Input GenBank flat-file: $GBIN
echo "${PBS_ARRAY_INDEX}":...Output FASTA: $SEQOUT

time ./03-prot-hash.pl <(cat part00 part01 part02 part03 part04 part05 part06 part07 part08 part09 part10 part11 part12 part13 part14 part15 part16 part17) "${GBIN}" > "${TMPW}/${PBS_ARRAY_INDEX}.fasta"

#
# Now copy results from TMP directory to final output location...
#

cp "${TMPW}/${PBS_ARRAY_INDEX}.fasta" "${SEQOUT}"
rm -rf "${TMPW}"
```
03-prot-hash.pl

**Note:** information from 'strand' determines the printed ordering 
```
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

my $delay_count = 0;
my $delay_seconds = 0;

# print $input_fn , "\n";
open $input_fh, '<', $input_fn or die 'Could not open file: ', $OS_ERROR;
while ( my $line = <$input_fh> ) {
    chomp $line;
    last if ! $line;
    my ($accession,$version,$gi) = split /,/, $line, 3;
    $hhash->{"$accession.$version"} = $gi;
    # print $hhash->{"$accession.$version"}, "\n";
    # sleep 1;
}

eval {
    $seqio_object = Bio::SeqIO->new( -file => $genbFile
                                   , -format => 'Genbank'
                                   );
};

if( $@ ) {
    print " Error: $@ ";
    exit(-1);
}

while ( my $seq_object= $seqio_object->next_seq()) {
    $genbank_accession = $seq_object->accession;
    $genbank_version   = $seq_object->seq_version;
    for my $feat_object ($seq_object->get_SeqFeatures) {
        if ( $feat_object->primary_tag eq 'source' ) {
            for my $tag ($feat_object->get_all_tags) {
                if ( $tag eq 'db_xref' ) {
                    for my $value ($feat_object->get_tag_values($tag)) {
                        if ($value =~ m/taxon:(\d+)/) {
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
            if ( $feat_object->location->isa('Bio::Location::SplitLocationI') ){
                my $sublocs = "";
                foreach $loc ( $feat_object->location->sub_Location ) {
                    if ( $loc->strand eq '1' ) {
                        $sublocs .= $loc->start_pos_type . ":" . $loc->start . ".." . $loc->end_pos_type . ":" . $loc->end . " ,";
                    }
                    else {
                        $sublocs .= $loc->end_pos_type . ":" . $loc->end . ".." . $loc->start_pos_type . ":" . $loc->start . " ,";
                    }
                }
                if ( $sublocs =~ m/(.*),$/) {
                    $genbank_protein_location = $1;
                }
                else {
                    $genbank_protein_location = "UNKNOWN-SPLIT";
                } 
            }
            else {
                $genbank_protein_location = $feat_object->location->start . ".." . $feat_object->location->end; 
            }
            #
            # Extract Features
            #
            for my $tag ($feat_object->get_all_tags) {
                # print "...", $tag, ":";
                if ( $tag eq 'protein_id' ) {
                    for my $tvalue ($feat_object->get_tag_values($tag)) {
                        $genbank_protein_id = $tvalue;
                    }
                    # print $genbank_protein_id, "\n";
                }
                if ( $tag eq 'translation' ) {
                    for my $tvalue ($feat_object->get_tag_values($tag)) {
                        $genbank_protein_translation = $tvalue;
                    }
                    # print $genbank_protein_translation, "\n";
                }
                if ( $tag eq 'product' ) {
                    for my $tvalue ($feat_object->get_tag_values($tag)) {
                        $genbank_protein_product = $tvalue;
                    }
                    # print $genbank_protein_product, "\n";
                }
                if ( $tag eq 'codon_start' ) {
                    for my $tvalue ($feat_object->get_tag_values($tag)) {
                        $genbank_protein_codonStart = $tvalue;
                    }
                    # print $genbank_protein_codonStart, "\n";
                }
            }
            eval {
                $nlookupval = $hhash->{"$genbank_accession.$genbank_version"};
            };
            if( $@ ) {
                $nlookupval = "NOT FOUND";
            } 
            eval {
                $plookupval = $hhash->{"$genbank_protein_id"};
            };
            if( $@ ) {
                $plookupval = "NOT FOUND";
            } 
            #
            # Print the protein entry to Fasta file here
            #
            print ">GI|GI:", $nlookupval, "|", $genbank_accession, ".", $genbank_version, "|", $genbank_protein_id , "|GI:", $plookupval, "|", $genbank_protein_product, "|", $seq_object->desc, ";pos=", $genbank_protein_location, ";codonStart=", $genbank_protein_codonStart, ";taxId=", $genbank_taxonomy_id, "\n";
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
```

### Part 6: Build BBmap virus database

**Code files:**

* [60-construct-bbmap.sh](./60-construct-bbmap.sh)

**Notes:**

Requires 30-45G RAM - max heap size is specified as 40G.

Runtime: < 10 minutes (16 cores)

**Usage:**

Paramaters:

1. Path to the nucleotide FASTA files generated in [Part 4](#part-4-nucleotide-fasta-generation-using-katana-pbs-script)

2. Path to output the database folder (default: `./virBbmap`)

```bash
./60-construct-bbmap.sh path/to/genbank/nucleotide/fasta ./virBbmap
```

**Gadi PBS script:**

61-pbs-60-construct-bbmap.sh

```bash
#!/bin/bash
#PBS -l nodes=1:ppn=48
#PBS -l mem=64GB
#PBS -l walltime=03:00:00
#
# Assumes you have followed previous section Part 4: Nucleotide .fasta generation
# Expected form of qsub:
#
# qsub 61-pbs-60-construct-bbmap.sh
#
cd "${PBS_O_WORKDIR}"
time ./60-construct-bbmap.sh /g/data/u71/VirMap/fasta-referencedbs/nucleotide /g/data/u71/VirMap/191126-virbb
./
```
### Part 7: Build Diamond virus database

**Code files:**

* [70-construct-virdmnd.sh](./70-construct-virdmnd.sh)

**Notes:**

Runtime: < 5 minutes (16 cores)

**Usage:**

Paramaters:

1. Path to the protein FASTA files generated in [Part 5](#part-5-protein-fasta-generation-using-katana-pbs-script)

2. Path to output the database file (default: `./virDmnd`)

```bash
./70-construct-virdmnd.sh path/to/genbank/protein/fasta ./virDmnd
```

# Part 8: Build Kraken2 database

**Code files:**

* [80-construct-kraken2.sh](./80-construct-kraken2.sh)

**Notes:**

This is an optional step, only required if use of `krakenFilter` is desired.

Also see: [VirMap Parameters](../parameters.md)

Requires: 50-80G RAM

Runtime: 2-3 hours (48 cores - Gadi)

**Usage:**

Paramaters:

1. Path to the nucleotide FASTA files generated in [Part 4](#part-4-nucleotide-fasta-generation-using-katana-pbs-script)

2. Path to output the database folder (default: `./krakenDb`)

3. Number of threads to use (default: autodetected)

```bash
./80-construct-kraken2.sh path/to/genbank/nucleotide/fasta ./krakenDb
```
