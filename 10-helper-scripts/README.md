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

### Part 5: Protein .fasta generation using Katana PBS script

