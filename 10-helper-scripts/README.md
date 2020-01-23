# VirMAP helper scripts

## Quicklinks

- [Taxonomy database](#part-1-taxonomy-database-generation)
- [Accession -> GI lookup](#part-2-accession---gi-lookup)
- [Genbank downloads](#part-3-genbank-division-download)
- [Nucleotide .fasta generation](#part-4-nucleotide-fasta-generation-using-gadi-pbs-script)
- [Protein .fasta generation](#part-5-protein-fasta-generation-using-gadi-pbs-script)
- [Build BBmap virus database](#part-6-build-bbmap-virus-database)
- [Build Diamond virus database](#part-7-build-diamond-virus-database)
- [Build Diamond genbank database (gbBlastx)](#part-7.5-build-diamond-genbank-database-gbblastx)
- [Build Kraken2 database](#part-8-build-kraken2-database)
- [Build blastn genbank database (gbBlastn)](#Part-9:-Build-blastn-genbank-database-gbBlastn)

## Gadi specific instructions

Jobs submitted to Gadi share a set of common arguments (specifying project, jobfs and storage requirements). To avoid repeating these everywhere, we store them in a shell variable. Which is assumed to have been executed/loaded before running any `qsub` commands in the rest of this document.

### Common qsub args snippet

```bash
# Use the u71 project and request its scratch and gdata folders be available
# along with 300GB of jobfs space (i.e. space under $TMP_DIR during a job)
COMMON_QSUB_ARGS="-P u71 -lstorage=scratch/u71+gdata/u71,jobfs=300GB"
```

However, you may use either of these equivalent forms:

- Run the snippet above to set the `COMMON_QSUB_ARGS` shell variable and use `$$COMMON_QSUB_ARGS` in `qsub` parameters:
  - e.g.

  ```bash
  COMMON_QSUB_ARGS="-P u71 -lstorage=scratch/u71+gdata/u71,jobfs=300GB"

  # Later ...

  qsub $COMMON_QSUB_ARGS -other -args -as -required script.sh

  qsub $COMMON_QSUB_ARGS -more -other -args -as -required script2.sh
  ```

- Include the parameters verbatim in the `qsub` parameters:
  - e.g.

  ```bash
  qsub -P u71 -lstorage=scratch/u71+gdata/u71,jobfs=300GB -other -args -as -required script.sh

  qsub -P u71 -lstorage=scratch/u71+gdata/u71,jobfs=300GB -more -other -args -as -required script2.sh
  ```

In an effort to keep sample commands short, but still executable, this document makes use of the former format.

### Part 1: Taxonomy database generation

#### Code files

- 10-construct-taxa/10-construct-taxa.pl

#### Usage

```bash
cd 10-construct-taxa
./01-construct-taxa.sh
cd ..
```

### Part 2: Accession -> GI lookup

```bash
qsub $COMMON_QSUB_ARGS -l walltime=1:00:00,mem=32G,ncpus=8,wd -j oe -N 02-sort-GbAccList.sh <<EOF
#!/bin/bash
GBACCLIST=GbAccList.0602.2019
wget https://ftp.ncbi.nih.gov/genbank/livelists/${GBACCLIST}.gz

# Note: If pigz is unavailable, substitute with gzip instead
# The --buffer-size can be tuned as available, a smaller buffer will
# result in a slower completion. Similarly, replace 32 with number of cores.
#
# N.B. On Gadi: Don't forget to request sufficient jobfs, as sort will
# perform an external sort, requiring space in $TMPDIR (e.g. -l jobfs=150GB)
pigz -dc "${GBACCLIST}.gz" |
  sort --parallel=8 --buffer-size=30G > "${GBACCLIST}.sort"
EOF
```

### Part 3: Genbank division download

```bash
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
```

### Part 4: Nucleotide .fasta generation using Gadi PBS script

#### Code files

- [03-hash.pl](./03-hash.pl)
- [05-genbank-fasta-nucleo.sh](./05-genbank-fasta-nucleo.sh)

#### Notes

Genbank divisions are expected to still be in their compressed `.seq.gz` form.

`05-genbank-fasta-nucleo.sh` will abort if the `parallel` utility is missing
and more than 1 thread is requested. Ensure either the appropriate module is loaded
or a suitable Conda environment is activated.

#### Usage

Parameters:

1. Path to sorted `GbAccList.sort` from [Part 2](#part-2-accession---gi-lookup)

2. Path to folder containing Genbank divisions from [Part 3](#part-3-genbank-division-download)

3. Number of threads to use (default: autodetected)

```bash
./05-genbank-fasta-nucleo.sh path/to/sorted/GbAccList path/to/genbank/divisions
```

Expected `qsub` usage:

```bash
qsub $COMMON_QSUB_ARGS -l walltime=4:00:00,mem=48G,ncpus=48,wd -j oe -N 05-genbank-fasta-nucleo.sh <<EOF
  source /scratch/u71/sy0928/tmp/virmap/activate.sh
  ./05-genbank-fasta-nucleo.sh path/to/sorted/GbAccList path/to/genbank/divisions
EOF
```

### Part 5: Protein .fasta generation using Gadi PBS script

#### Code files

- [03-prot-hash.pl](./03-prot-hash.pl)
- [05-genbank-fasta-protein.sh](./05-genbank-fasta-protein.sh)

#### Notes

Genbank divisions are expected to still be in their compressed `.seq.gz` form.

The entire `GbAccList.sort` fill will be copied to `/dev/shm`.

`05-genbank-fasta-protein.sh` will abort if the `parallel` utility is missing
and more than 1 thread is requested. Ensure either the appropriate module is loaded
or a suitable Conda environment is activated.

Runtime: Approx 2 hours (48 cores - Gadi)

Information from 'strand' determines the printed ordering.

#### Usage

Parameters:

1. Path to sorted `GbAccList.sort` from [Part 2](#part-2-accession---gi-lookup)

2. Path to folder containing Genbank divisions from [Part 3](#part-3-genbank-division-download)

3. Number of threads to use (default: autodetected)

```bash
./05-genbank-fasta-protein.sh path/to/sorted/GbAccList path/to/genbank/divisions
```

Expected `qsub` usage:

```bash
qsub $COMMON_QSUB_ARGS -l walltime=4:00:00,mem=48G,ncpus=48,wd -j oe -N 05-genbank-fasta-protein.sh <<EOF
  source /scratch/u71/sy0928/tmp/virmap/activate.sh
  ./05-genbank-fasta-protein.sh path/to/sorted/GbAccList path/to/genbank/divisions
EOF
```

### Part 6: Build BBmap virus database

#### Code files

- [60-construct-bbmap.sh](./60-construct-bbmap.sh)

#### Notes

Requires 30-45G RAM - max heap size is specified as 40G.

Runtime: < 10 minutes (16 cores)

#### Usage

Parameters:

1. Path to the nucleotide FASTA files generated in [Part 4](#part-4-nucleotide-fasta-generation-using-gadi-pbs-script)

2. Path to output the database folder (default: `./virBbmap`)

```bash
./60-construct-bbmap.sh path/to/genbank/nucleotide/fasta ./virBbmap
```

#### Gadi PBS script

61-pbs-60-construct-bbmap.sh

```bash
#!/bin/bash
#PBS -l ncpus=48
#PBS -l mem=64GB
#PBS -l walltime=03:00:00
#
# Assumes you have followed previous section Part 4: Nucleotide .fasta generation
# Expected form of qsub:
#
# qsub 61-pbs-60-construct-bbmap.sh
#
cd "${PBS_O_WORKDIR}"

MINICONDA_DIR=/scratch/u71/sy0928/tmp/miniconda3
source $MINICONDA_DIR/etc/profile.d/conda.sh

INSTALL_DIR=/scratch/u71/sy0928/tmp/virmap
source $INSTALL_DIR/activate.sh

time ./60-construct-bbmap.sh /g/data/u71/VirMap/fasta-referencedbs/nucleotide /g/data/u71/VirMap/191126-virbb
```

### Part 7: Build Diamond virus database

#### Code files

- [70-construct-virdmnd.sh](./70-construct-virdmnd.sh)

#### Notes

Runtime: < 5 minutes (16 cores)

#### Usage

Parameters:

1. Path to the protein FASTA files generated in [Part 5](#part-5-protein-fasta-generation-using-gadi-pbs-script)

2. Path to output the database file (default: `./virDmnd`)

```bash
./70-construct-virdmnd.sh path/to/genbank/protein/fasta ./virDmnd
```

#### Gadi PBS script

71-pbs-70-construct-virdmnd.sh

```bash
#!/bin/bash
#PBS -l ncpus=48
#PBS -l mem=64GB
#PBS -l walltime=03:00:00
#
# Assumes you have followed previous section Part 5: Protein .fasta generation
# Expected form of qsub:
#
# qsub 71-pbs-70-construct-virdmnd.sh
#
cd "${PBS_O_WORKDIR}"

MINICONDA_DIR=/scratch/u71/sy0928/tmp/miniconda3
source $MINICONDA_DIR/etc/profile.d/conda.sh

INSTALL_DIR=/scratch/u71/sy0928/tmp/virmap
source $INSTALL_DIR/activate.sh

time ./70-construct-virdmnd.sh /g/data/u71/VirMap/fasta-referencedbs/protein /g/data/u71/VirMap/191127-virdiamond
```

### Part 7.5: Build Diamond genbank database (gbBlastx)

#### Code files

- [75-construct-gbblastx.sh](./75-construct-gbblastx.sh)

#### Notes

Generates a diamond database from all the used GenBank divisions.

Runtime: < 15 minutes (48 cores - Gadi)

#### Usage

Parameters:

1. Path to the protein FASTA files generated in [Part 5](#part-5-protein-fasta-generation-using-gadi-pbs-script)

2. Path to output the database file (default: `./gbBlastx`)

```bash
./75-construct-gbblastx.sh path/to/genbank/protein/fasta ./gbBlastx
```

#### Gadi PBS script

`76-pbs-75-construct-gbblastx.sh`

```bash
#!/bin/bash
#PBS -l ncpus=48
#PBS -l mem=64GB
#PBS -l walltime=03:00:00
#PBS -j oe
#PBS -l wd
#
# Assumes you have followed previous section Part 5: Protein .fasta generation
# Expected form of qsub:
#
# qsub 76-pbs-75-construct-gbblastx.sh
#

source /scratch/u71/sy0928/tmp/virmap/activate.sh

time ./75-construct-gbblastx.sh /g/data/u71/VirMap/fasta-referencedbs/protein /g/data/u71/VirMap/191127-gbBlastx
```

### Part 8: Build Kraken2 database

#### Code files

- [80-construct-kraken2.sh](./80-construct-kraken2.sh)

#### Notes

This is an optional step, only required if use of `krakenFilter` is desired.

Also see: [VirMap Parameters](../parameters.md)

Due to the use of `parallel` to speed up fasta ingestion, the default `maximum open file descriptors` (`ulimit -n`) may be too small on some systems for the number of threads chosen. 87 per thread is a ballpark guess of the max number of descriptors required.

Requires: 50-80G RAM

Runtime: 2-3 hours (48 cores - Gadi)

#### Usage

Parameters:

1. Path to the nucleotide FASTA files generated in [Part 4](#part-4-nucleotide-fasta-generation-using-gadi-pbs-script)

2. Path to output the database folder (default: `./krakenDb`)

3. Number of threads to use (default: autodetected)

Also accepts parameters via `GENBANK_NUC`, `DEST_DB`, `NCPUS` environment variables.

```bash
./80-construct-kraken2.sh path/to/genbank/nucleotide/fasta ./krakenDb
```

Expected `qsub` usage (cd'd to `10-helper-scripts`):

```bash
qsub $COMMON_QSUB_ARGS -l walltime=6:00:00,mem=80G,ncpus=48,wd -j oe -N 80-construct-kraken2.sh <<EOF
  source /scratch/u71/sy0928/tmp/virmap/activate.sh
  ./80-construct-kraken2.sh /path/to/genbank/nucleotide/fasta ./krakenDb
EOF
```

### Part 9: Build blastn genbank database (gbBlastn)

#### Code files

- [90-construct-gbblastn.sh](./90-construct-gbblastn.sh)

#### Notes

Generates a diamond database from all the used GenBank divisions.

`makeblastdb` is singlethreaded, so 2 cores would be sufficient (`makeblastdb` + `sed`). On Gadi, however, SU is charged based on the greater of cores and mem/4 so we may as well request 8 cores to speed up the preprocessing slightly.

Requires at least 2GB space in `$TMPDIR` (as found by `mktemp`).

Runtime: Approx 1 hour (Gadi)

#### Usage

Parameters:

1. Path to the nucleotide FASTA files generated in [Part 4](#part-4-nucleotide-fasta-generation-using-gadi-pbs-script)

2. Path to output the database file (default: `./gbBlastn`)

```bash
./90-construct-gbblastn.sh path/to/genbank/nucleotide/fasta ./gbBlastn
```

#### Gadi PBS script

`91-pbs-90-construct-gbblastn.sh`

```bash
#!/bin/bash
#PBS -l ncpus=8
#PBS -l mem=32GB
#PBS -l walltime=02:00:00
#PBS -j oe
#PBS -l wd
#PBS -l jobfs=5GB
#
# Assumes you have followed previous section Part 4: Nucleotide .fasta generation
# Expected form of qsub:
#
# qsub 91-pbs-90-construct-gbblastn.sh
#

source /scratch/u71/sy0928/tmp/virmap/activate.sh

time ./90-construct-gbblastn.sh /g/data/u71/VirMap/fasta-referencedbs/nucleotide /g/data/u71/VirMap/191127-gbBlastn
```
