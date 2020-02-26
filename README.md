# VirMAP + Dockerfile + FASTA Headers
In July 2019, this group was formed with the aim of getting the VirMAP pipeline to work on NCI Raijin.  

Where do I find what I'm looking for? 

**More background information** - all this goes into /docs

**Progress and critical issues tracking** - check out /worklogs

**Docker container** - a Dockerfile is at the root of this repository

**Reference databases** - see /referencedbs

**VirMAP parameter descriptions** - see [parameters](./parameters.md)

### Installation and Setup
**Important:** Complete the installation steps below first.  Then proceed to https://github.com/rsoftone/virmap/tree/master/10-helper-scripts to setup databases (from NCBI Taxonomy and Genbank)
  
```
#!/bin/bash
# Raijin specific: $TMPDIR is /short/<some-project>/<some-uid>/tmp
# 
# All build and installation will be prefixed in $TMPDIR
#
# Download and install Miniconda
#
INSTALL_DIR=$TMPDIR/virmap
MINICONDA_DIR=$TMPDIR/miniconda3

cd $TMPDIR

wget https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O $TMPDIR/miniconda.sh

#
# The next line is Raijin specific (we prefix the environments to store them in my $MINICONDA_DIR directory)
#

/bin/bash $TMPDIR/miniconda.sh -u -b -p $MINICONDA_DIR

# sudo yum install -y openssl-devel

# If using Ubuntu Server 18:
sudo apt-get install build-essential openssl libssl-dev zlib1g-dev


mkdir $INSTALL_DIR
cd $INSTALL_DIR
source $MINICONDA_DIR/etc/profile.d/conda.sh

cat - <<EOF >environment.yml 
name: virmap
channels:
- bioconda
- agbiome
- conda-forge
- defaults
dependencies:
- diamond
- blast
- bbmap=38.67 # versions after this introduce spaces into the fasta header
- megahit
- khmer
- vsearch
- lbzip2
- pigz
- zstd
- sra-tools
- coreutils
- kraken2
- parallel
- pv # not strictly required
EOF

#
# Create Conda Environment
#
#  The next line is Raijin specific.  We need ~10GB  space to hold the source packages…
# and Raijin $HOME is very limited in space…
#
#
# The lines below are no longer needed for Gadi (re-enable them if you are on Raijin)
#
# export CONDA_PKGS_DIRS=/short/yi98/sy0928/pkgs
#

conda env create -f environment.yml 

#
# Finished Anaconda packages...proceed to Perl and associated packages
#

wget http://www.cpan.org/src/5.0/perl-5.28.0.tar.gz -O $TMPDIR/perl-5.28.0.tar.gz
cd $TMPDIR && tar zxvf perl-5.28.0.tar.gz
cd perl-5.28.0

#
# The lines below are no longer needed for Gadi (re-enable them if you are on Raijin)
#
# module load gcc/4.9.0
# export CC=/apps/gcc/4.9.0/wrapper/gcc

#
# On Raijin: this will build a multithreaded Perl with gcc 4.9 (needed for C++11), without Perl docs
# On Gadi: We can use system gcc, and omit -Dcc=..
#

#
# The lines below are no longer needed for Gadi (re-enable them if you are on Raijin)
#
# ./Configure -des -Dusethreads -Dprefix=$INSTALL_DIR -Dcc=/apps/gcc/4.9.0/wrapper/gcc -Dman1dir=none -Dman3dir=none

./Configure -des -Dusethreads -Dprefix=$INSTALL_DIR -Dman1dir=none -Dman3dir=none
make
make install

#
# Finished Perl 5.28.0...proceed to install VirMap itself
#

cd $INSTALL_DIR && git clone https://github.com/cmmr/virmap.git

#
# binutils is old on Raijin...load a module with updated /bin/as
#

#
# The lines below are no longer needed for Gadi (re-enable them if you are on Raijin)
#
# module load binutils/2.32

#
# Setup a simple activation script, usage:
# source $INSTALL_DIR/activate.sh
#

cat - <<EOF >$INSTALL_DIR/activate.sh
INSTALL_DIR=$INSTALL_DIR
MINICONDA_DIR=$MINICONDA_DIR

#
# Setup conda in the shell and activate the environment
#
source "\$MINICONDA_DIR/etc/profile.d/conda.sh"
conda activate virmap

#
# Get suitable PATH for VirMap and Perl 5.28.0
#
export PERL5LIB=\$INSTALL_DIR/lib/perl5
export PATH=\$INSTALL_DIR/virmap:\$INSTALL_DIR/bin:\$PATH
EOF

#
#
#

conda activate virmap
export PERL5LIB=$INSTALL_DIR/lib/perl5
export PATH=$INSTALL_DIR/virmap:$INSTALL_DIR/bin:$PATH

cpan App::cpanminus

#
# For RocksDB (make sure environment variable CC is set correctly!)
#

cpanm --local-lib=$INSTALL_DIR --force RocksDB

#
# For other dependencies
#



cpanm --local-lib=$INSTALL_DIR OpenSourceOrg::API

cpanm --local-lib=$INSTALL_DIR --force POSIX::1003::Sysconf

cpanm --local-lib=$INSTALL_DIR --force POSIX::RT::Semaphore

cpanm --local-lib=$INSTALL_DIR Compress::Zstd

# Sereal::Decoder can have trouble compiling the Zstd lib on Gadi, but will
# happily compile against existing zstd, even though it can't use it properly.
# Sereal's internal support for Zstd (i.e. *not* what is used by VirMap)
# will be broken, and tests for that fail
module load zstd
cpanm --local-lib=$INSTALL_DIR --force Sereal
module unload zstd

cpanm --local-lib=$INSTALL_DIR Text::Levenshtein::Damerau::XS

cpanm --local-lib=$INSTALL_DIR Text::Levenshtein::XS

cpanm --local-lib=$INSTALL_DIR Statistics::Basic

cpanm --local-lib=$INSTALL_DIR Cpanel::JSON::XS

module unload binutils

cd $INSTALL_DIR/lib/perl5 && wget https://raw.githubusercontent.com/ucdavis-bioinformatics/assemblathon2-analysis/master/FAlite.pm
cd ~

#
# Test the Perl installation
#

perl -e 'use Compress::Zstd; use English; use Thread::Semaphore; use Thread::Queue qw( ); use threads::shared; use strict; use RocksDB; use Statistics::Basic qw(:all); use Sereal; use Text::Levenshtein::XS; use Text::Levenshtein::Damerau::XS; use OpenSourceOrg::API; use POSIX::1003::Sysconf; use POSIX::RT::Semaphore; use FAlite'

```
### Testing VirMAP
```

# First logout, then login again to Raijin
#

# You'll want to substitute $INSTALL_DIR here manually,
# as it was set in the previous session
source $INSTALL_DIR/activate.sh

# module load gcc/4.9.0

Virmap.pl

# This should return:
# usage: Virmap.pl [options] <databases> --readF ReadSet1_R1.fastq.bz2 ReadSet2_R1.fastq.gz --readR ReadSet1_R2.fastq.bz2 ReadSet2_R2.fastq.bz2 --readUnpaired ReadsUnpaired.fastq.bz2

# Test dependent application...
which megahit

# This should return:
# $MINICONDA_DIR/envs/virmap/bin/megahit
```

### VirMAP wrapper script

A wrapper script `virmap_wrapper.sh` is provided in this repository, which can:

* Store common parameters (e.g. database paths) in a config file `virmap_config.sh`
* Perform database parameter sanity checks
* Automatically setup the environment (sources `activate.sh`)

#### Setup

```bash
# Copy the wrapper script into the directory where we installed VirMAP
cp -s virmap_wrapper.sh "$INSTALL_DIR/"

# Run the wrapper once to generate a template config file
"$INSTALL_DIR/virmap_wrapper.sh"

# Fill the config file with database paths
edit "$INSTALL_DIR/virmap_config.sh"
```

#### Sample usage

##### Without wrapper script

```bash
qsub -P u71 -q normal -l walltime=6:00:00,mem=48G,ncpus=12,wd,jobfs=100GB,storage=scratch/u71+gdata/u71 -joe <<EOF
    source $INSTALL_DIR/activate.sh
    Virmap.pl \
        --readUnpaired "/path/to/my/sample.fastq" \
        --outputDir "/path/to/my/sample/output_dir" \
        --tmp "/path/to/my/sample/output_tmp" `# Optional` \
        --sampleName "sample_name" \
        --threads "48" \
        --gbBlastx "/g/data1a/u71/VirMap/191205-gbblastx.dmnd" \
        --gbBlastn "/g/data1a/u71/VirMap/191205-gbBlastn/191205-gbBlastn" \
        --virBbmap "/g/data1a/u71/VirMap/191205-virBbmap" \
        --virDmnd "/g/data1a/u71/VirMap/191205-virdiamond.dmnd" \
        --taxaJson "/g/data1a/u71/VirMap/taxaJson.dat"
EOF
```

##### With wrapper script

```bash
cd /path/to/store/output
qsub -P u71 -q normal -l walltime=6:00:00,mem=48G,ncpus=12,wd,jobfs=100GB,storage=scratch/u71+gdata/u71 -joe -- \
    $INSTALL_DIR/virmap_wrapper.sh \
        --readUnpaired "/path/to/my/sample/.fastq" \
        --sampleName "sample_name"
```
