#!/bin/bash
# Raijin specific: $MY_TMPDIR is /short/<some-project>/<some-uid>/tmp
# 
# All build and installation will be prefixed in $MY_TMPDIR
#
# Download and install Miniconda
#

## Please replace $MY_TMPDIR with the location of the directory where you want to Virmap source, executables and conda environment
MY_TMPDIR=/g/data/projectID/subdirectory   #/g/data/projectID/igy/tmp

## Igy add this line to change the TMPDIR
export TMPDIR=$MY_TMPDIR

if [[ ! -d $MY_TMPDIR ]]; then
  mkdir -p $MY_TMPDIR
fi

INSTALL_DIR=$MY_TMPDIR/virmap
MINICONDA_DIR=$MY_TMPDIR/miniconda3

cd $MY_TMPDIR

wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.3-Linux-x86_64.sh -O $MY_TMPDIR/miniconda.sh

#
# The next line is Raijin specific (we prefix the environments to store them in my $MINICONDA_DIR directory)
#

/bin/bash $MY_TMPDIR/miniconda.sh -u -b -p $MINICONDA_DIR

# sudo yum install -y openssl-devel

# If using Ubuntu Server 18:
# sudo apt-get install build-essential openssl libssl-dev zlib1g-dev

if [[ ! -d $INSTALL_DIR ]]; then
  mkdir -p $INSTALL_DIR
fi

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
- xlsxwriter
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

wget http://www.cpan.org/src/5.0/perl-5.28.0.tar.gz -O $MY_TMPDIR/perl-5.28.0.tar.gz
cd $MY_TMPDIR && tar zxvf perl-5.28.0.tar.gz
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

# ==> WARNING: A newer version of conda exists. <==
#   current version: 4.5.11
#   latest version: 4.8.3
# 
# Please update conda by running
# 

#     $ conda update -n base -c defaults conda
