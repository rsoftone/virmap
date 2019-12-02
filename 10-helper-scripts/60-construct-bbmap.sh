#!/usr/bin/env bash
# 60-construct-bbmap.sh
#
function usage() {
    printf "\nUsage: ./60-construct-bbmap.sh path/to/genbank/nucleotide/fasta [outputLocation]\n"
}
#
# Description:
#     Helper script for building a bbmap database from FASTA formatted 
#     Genbank Nucleotide divisions gbvrl and gbphp.

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

set -o errexit
set -o nounset
set -o pipefail

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

GENBANK_NUC="$1"
DEST_DB="${2:-virBbmap}"
RAM='40g'
THREADS='auto'

if ! ls "$GENBANK_NUC" >/dev/null; then
    exit 1
fi
if [[ -e "$DEST_DB" ]]; then
    echo "[!] Output path $(printf "%q" "$DEST_DB") should not already exist."
    exit 1
fi

printf '%s\0' "$GENBANK_NUC/gbphg"*.fasta "$GENBANK_NUC/gbvrl"*.fasta | sort -zV | xargs -0 cat |
    bbmap.sh -Xms"$RAM" -Xmx"$RAM" threads="$THREADS" ref=stdin path="$DEST_DB"
