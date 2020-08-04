#!/bin/bash -e
# Katana specific: $SCRATCHDIR is /srv/scratch/$USER/virmap
# 
# All build and installation will be prefixed in $SCRATCHDIR
#
# Download and install Miniconda
#
SCRATCHDIR=/srv/scratch/$USER/virmap

mkdir -p ${SCRATCHDIR}

INSTALL_DIR=$SCRATCHDIR/virmap
MINICONDA_DIR=$SCRATCHDIR/miniconda3

cd $SCRATCHDIR
echo -e "\n-------------\nInstalling Conda into ${MINICONDA_DIR}.\n----------\n"

wget https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O $SCRATCHDIR/miniconda.sh

#
# The next line is Raijin specific (we prefix the environments to store them in my $MINICONDA_DIR directory)
#

/bin/bash $SCRATCHDIR/miniconda.sh -u -b -p $MINICONDA_DIR

mkdir $INSTALL_DIR
cd $INSTALL_DIR
source $MINICONDA_DIR/etc/profile.d/conda.sh

# Because we want to keep with Python 3.7 we use this approach rather than an environment.yml file.

conda create -y -n virmap python=3.7
conda activate virmap

export PKG="diamond blast bbmap=38.67 megahit khmer vsearch lbzip2 pigz zstd sra-tools coreutils kraken2 parallel pv"

conda install -y $PKG --channel bioconda --channel agbiome --channel conda-forge --channel defaults

#
# Finished Anaconda packages...proceed to Perl and associated packages
#

echo -e "\n-------------\nInstalling Perl into ${SCRATCHDIR}/perl-5.28.0.\n----------\n"

wget http://www.cpan.org/src/5.0/perl-5.28.0.tar.gz -O $SCRATCHDIR/perl-5.28.0.tar.gz
cd $SCRATCHDIR && tar zxvf perl-5.28.0.tar.gz
cd perl-5.28.0

# ./Configure -des -Dusethreads -Dprefix=$INSTALL_DIR

./Configure -des -Dusethreads -Dprefix=$INSTALL_DIR -Dman1dir=none -Dman3dir=none
make
make install

#
# Finished Perl 5.28.0...proceed to install VirMap itself
#
echo -e "\n-------------\nInstalling VirMap!!!.\n----------\n"

cd $INSTALL_DIR && git clone https://github.com/cmmr/virmap.git

# Setup a simple activation script, usage:
# source $INSTALL_DIR/activate.sh
#
echo -e "\n-------------\nCreating activation script.\n----------\n"

cat - <<EOF >$INSTALL_DIR/activate_virmap.sh
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
echo -e "\n-------------\nInstalling Perl packages.\n----------\n"

export PERL5LIB=$INSTALL_DIR/lib/perl5
export PATH=$INSTALL_DIR/virmap:$INSTALL_DIR/bin:$PATH

cpan App::cpanminus

# Some of these really do need the --force option.

cpanm --local-lib=$INSTALL_DIR --force RocksDB

cpanm --local-lib=$INSTALL_DIR OpenSourceOrg::API

cpanm --local-lib=$INSTALL_DIR --force POSIX::1003::Sysconf

cpanm --local-lib=$INSTALL_DIR --force POSIX::RT::Semaphore

cpanm --local-lib=$INSTALL_DIR Compress::Zstd

cpanm --local-lib=$INSTALL_DIR --force Sereal

cpanm --local-lib=$INSTALL_DIR Text::Levenshtein::Damerau::XS

cpanm --local-lib=$INSTALL_DIR Text::Levenshtein::XS

cpanm --local-lib=$INSTALL_DIR Statistics::Basic

cpanm --local-lib=$INSTALL_DIR Cpanel::JSON::XS

cd $INSTALL_DIR/lib/perl5 && wget https://raw.githubusercontent.com/ucdavis-bioinformatics/assemblathon2-analysis/master/FAlite.pm
cd

#
# Test the Perl installation
#
echo -e "\n-------------\nTesting Perl packages.\n----------\n"

perl -e 'use Compress::Zstd; use English; use Thread::Semaphore; use Thread::Queue qw( ); use threads::shared; use strict; use RocksDB; use Statistics::Basic qw(:all); use Sereal; use Text::Levenshtein::XS; use Text::Levenshtein::Damerau::XS; use OpenSourceOrg::API; use POSIX::1003::Sysconf; use POSIX::RT::Semaphore; use FAlite'

echo -e "\n-------------\nVirMap is now installed. Time to set up the databases.\n----------\n"
