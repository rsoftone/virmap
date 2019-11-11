## Quicklinks
* [Taxonomy database](#part-1-taxonomy-database-generation)
* [Accession -> GI lookup](#part-2-accession---gi-lookup)
* [Genbank downloads](#part-3-genbank-division-download)
* [Nucleotide .fasta generation](#part-4-nucleotide-fasta-generation-using-katana-pbs-script)
* [Protein .fasta generation](#part-5-protein-fasta-generation-using-katana-pbs-script)

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
## Expected form of qsub:
##
## qsub -N "${PREFIXDB}"-protein -J 1-$(find "${GENBANKPATH}" -type f -name "${PREFIXDB}"*.seq|wc -l) -v PREFIXDB="${PREFIXDB}" 05-genbank-fasta-nucleo.sh 

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

