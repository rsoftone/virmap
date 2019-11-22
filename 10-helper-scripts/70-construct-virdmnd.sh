#!/usr/bin/env bash
# 70-construct-virdmnd.sh
#
function usage() {
    printf "\nUsage: ./70-construct-virdmnd.sh path/to/genbank/protein/fasta [outputLocation]\n"
}
#
# Description:
#     Helper script for building a Diamond database from FASTA formatted 
#     Genbank Protein divisions gbvrl and gbphp.

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

GENBANK_AA="$1"
DEST_DB="${2:-virDmnd}"

if ! ls "$GENBANK_AA" >/dev/null; then
    exit 1
fi
if [[ -e "$DEST_DB" ]]; then
    echo "[!] Output path $(printf "%q" "$DEST_DB") should not already exist."
    exit 1
fi

printf '%s\0' "$GENBANK_AA/gbphg"* "$GENBANK_AA/gbvrl"* | sort -zV | xargs -0 cat |
    diamond makedb -d "$DEST_DB"
