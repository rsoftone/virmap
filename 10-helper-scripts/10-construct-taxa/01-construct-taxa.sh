#!/bin/bash
# 01-construct-taxa.sh
#
# Usage: 
#     ./01-construct-taxa.sh
#
# Description: 
#     Helper script for converting NCBI Taxonomy data into the Sereal-encoded
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
# Setup required environment variables
#
export PERL5LIB=$TMPDIR/virmap/lib/perl5
export PATH=$TMPDIR/virmap/virmap:$TMPDIR/virmap/bin:$PATH
#
# Download NCBI taxonomy files
#
wget http://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
tar zxvf taxdump.tar.gz
rm -f taxdump.tar.gz

./10-construct-taxa.pl . && echo 'Finished generating taxaJson.dat'
