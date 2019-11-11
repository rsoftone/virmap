# VirMAP + Dockerfile + FASTA Headers
In July 2019, this group was formed with the aim of getting the VirMAP pipeline to work on NCI Raijin.  

Where do I find what I'm looking for? 

**More background information** - all this goes into /docs

**Progress and critical issues tracking** - check out /worklogs

**Docker container** - a Dockerfile is at the root of this repository

**Reference databases** - see /referencedbs

### Installation and Setup 
```
#!/bin/bash
# Raijin specific: $TMPDIR is /short/<some-project>/<some-uid>/tmp
# 
# All build and installation will be prefixed in $TMPDIR
#
# Download and install Miniconda
#

cd $TMPDIR

wget https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O $TMPDIR/miniconda.sh

#
# The next line is Raijin specific (we prefix the environments to store them in my $TMPDIR directory)
#

/bin/bash $TMPDIR/miniconda.sh -u -b -p $TMPDIR

# sudo yum install -y openssl-devel

mkdir $TMPDIR/virmap
source $TMPDIR/etc/profile.d/conda.sh

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
- bbtools
- megahit
- khmer
- vsearch
- lbzip2
- pigz
- zstd
- sra-tools
EOF

#
# Create Conda Environment
#
#  The next line is Raijin specific.  We need ~10GB  space to hold the source packages…
# and Raijin $HOME is very limited in space…
#
export CONDA_PKGS_DIRS=/short/yi98/sy0928/pkgs
#
conda env create -f environment.yml 

#
# Finished Anaconda packages...proceed to Perl and associated packages
#

wget http://www.cpan.org/src/5.0/perl-5.28.0.tar.gz -O $TMPDIR/perl-5.28.0.tar.gz
cd $TMPDIR && tar zxvf perl-5.28.0.tar.gz
cd perl-5.28.0

module load gcc/4.9.0
export CC=/apps/gcc/4.9.0/wrapper/gcc

#
# On Raijin: this will build a multithreaded Perl with gcc 4.9 (needed for C++11), without Perl docs
#

./Configure -des -Dusethreads -Dprefix=$TMPDIR/virmap -Dcc=/apps/gcc/4.9.0/wrapper/gcc -Dman1dir=none -Dman3dir=none

make
make install
module unload gcc/4.9.0

#
# Finished Perl 5.28.0...proceed to install VirMap itself
#

cd $TMPDIR/virmap && git clone https://github.com/cmmr/virmap.git
cd ~

#
# binutils is old on Raijin...load a module with updated /bin/as
#

module load binutils/2.32
export PERL5LIB=$TMPDIR/virmap/lib/perl5

# 
# Get suitable PATH for VirMap and Perl 5.28.0
#

export PATH=$TMPDIR/virmap/virmap:$TMPDIR/virmap/bin:$PATH
module load gcc/4.9.0

cpan App::cpanminus

#
# For RocksDB (make sure environment variable CC is set correctly!)
#

perl -MCPAN -e "CPAN::Shell->notest('install','RocksDB')"

#
# For other dependencies
#

cpanm --local-lib=$TMPDIR/virmap OpenSourceOrg::API

cpanm --local-lib=$TMPDIR/virmap --force POSIX::1003::Sysconf

cpanm --local-lib=$TMPDIR/virmap --force POSIX::RT::Semaphore

cpanm --local-lib=$TMPDIR/virmap Compress::Zstd

cpanm --local-lib=$TMPDIR/virmap Sereal

cpanm --local-lib=$TMPDIR/virmap Text::Levenshtein::Damerau::XS

cpanm --local-lib=$TMPDIR/virmap Text::Levenshtein::XS

cpanm --local-lib=$TMPDIR/virmap Statistics::Basic

module unload binutils

cd $TMPDIR/virmap/lib/perl5 && wget https://raw.githubusercontent.com/ucdavis-bioinformatics/assemblathon2-analysis/master/FAlite.pm
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

source $TMPDIR/etc/profile.d/conda.sh
conda activate virmap

export PATH=$TMPDIR/virmap/virmap:$TMPDIR/virmap/bin:$PATH
export PERL5LIB=$TMPDIR/virmap/lib/perl5
module load gcc/4.9.0

Virmap.pl

# This should return:
# usage: Virmap.pl [options] <databases> --readF ReadSet1_R1.fastq.bz2 ReadSet2_R1.fastq.gz --readR ReadSet1_R2.fastq.bz2 ReadSet2_R2.fastq.bz2 --readUnpaired ReadsUnpaired.fastq.bz2

# Test dependent application...
which megahit

# This should return:
# $TMPDIR/envs/virmap/bin/megahit
```
