#!/usr/bin/env bash
# 75-construct-gbblastx.sh
#
function usage() {
    printf "\nUsage: ./75-construct-gbblastx.sh path/to/genbank/protein/fasta [outputLocation]\n"
}
#
# Description:
#     Helper script for building a Diamond database from FASTA formatted
#     Genbank Protein divisions listed below.

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
DEST_DB="${2:-gbBlastx}"

if ! ls "$GENBANK_AA" >/dev/null; then
    exit 1
fi
if [[ -e "$DEST_DB" ]]; then
    echo "[!] Output path $(printf "%q" "$DEST_DB") should not already exist."
    exit 1
fi

GENBANK_DIV_FILES=(
    "$GENBANK_AA/gbbct"*.fasta
    "$GENBANK_AA/gbcon"*.fasta
    "$GENBANK_AA/gbenv"*.fasta
    "$GENBANK_AA/gbhtc"*.fasta
    "$GENBANK_AA/gbinv"*.fasta
    "$GENBANK_AA/gbmam"*.fasta
    "$GENBANK_AA/gbpat"*.fasta
    "$GENBANK_AA/gbphg"*.fasta
    "$GENBANK_AA/gbpln"*.fasta
    "$GENBANK_AA/gbpri"*.fasta
    "$GENBANK_AA/gbrod"*.fasta
    "$GENBANK_AA/gbsts"*.fasta
    "$GENBANK_AA/gbsyn"*.fasta
    "$GENBANK_AA/gbuna"*.fasta
    "$GENBANK_AA/gbvrl"*.fasta
    "$GENBANK_AA/gbvrt"*.fasta
)

# Output progress if pv is available
if command -v pv >/dev/null 2>/dev/null; then
    MAYBE_PV="pv -f"
else
    MAYBE_PV="cat"
fi

printf '%s\0' "${GENBANK_DIV_FILES[@]}" | sort -zV | xargs -0 $MAYBE_PV |
    diamond makedb -d "$DEST_DB"
