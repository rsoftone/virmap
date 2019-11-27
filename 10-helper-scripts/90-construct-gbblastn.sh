#!/usr/bin/env bash
# 90-construct-gbblastn.sh
#
function usage() {
    printf "\nUsage: ./90-construct-gbblastn.sh path/to/genbank/nucleotide/fasta [outputLocation] [threads]\n"
}
#
# Description:
#     Helper script for building a blastn database from FASTA formatted
#     Genbank Nucleotide divisions listed below.

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
DEST_DB="${2:-gbBlastx}"
THREADS="${3:-${PBS_NCPUS:-${NCPUS:-$(nproc)}}}"

echo "[ ] Using $THREADS threads"

if ! ls "$GENBANK_NUC" >/dev/null; then
    exit 1
fi
if [[ -e "$DEST_DB" ]]; then
    echo "[!] Output path $(printf "%q" "$DEST_DB") should not already exist."
    exit 1
fi

GENBANK_DIV_FILES=(
    "$GENBANK_NUC/gbbct"*
    "$GENBANK_NUC/gbcon"*
    "$GENBANK_NUC/gbenv"*
    "$GENBANK_NUC/gbhtc"*
    "$GENBANK_NUC/gbinv"*
    "$GENBANK_NUC/gbmam"*
    "$GENBANK_NUC/gbpat"*
    "$GENBANK_NUC/gbphg"*
    "$GENBANK_NUC/gbpln"*
    "$GENBANK_NUC/gbpri"*
    "$GENBANK_NUC/gbrod"*
    "$GENBANK_NUC/gbsts"*
    "$GENBANK_NUC/gbsyn"*
    "$GENBANK_NUC/gbuna"*
    "$GENBANK_NUC/gbvrl"*
    "$GENBANK_NUC/gbvrt"*
)

TAX_MAP_FILE=$(mktemp)

# Construct a simple accession-taxid mapping as makeblastdb can't take it from
# the header directly
time printf '%s\0' "${GENBANK_DIV_FILES[@]}" | sort -zV | parallel --keep-order -j"$THREADS" -0tI '{}' \
    grep -e "'^>'" '{}' '|' \
    sed -e "'s/^>gi|[^|]*|gb|\([^|]*\)|.*taxId=\([0-9]*\)/\1 \2/g'" '|' \
    uniq >"$TAX_MAP_FILE"
wc -l "$TAX_MAP_FILE"

# Output progress if pv is available
if command -v pv >/dev/null 2>/dev/null; then
    MAYBE_PV="pv -f"
else
    MAYBE_PV="cat"
fi

# Modify the headers to only contain the accession number
printf '%s\0' "${GENBANK_DIV_FILES[@]}" | sort -zV | xargs -0 $MAYBE_PV |
    sed -e 's/^>gi|[^|]*|gb|\([^|]*\)|.*taxId=\([0-9]*\)/>\1/g' |
    makeblastdb -blastdb_version 5 -parse_seqids -out "$DEST_DB" -dbtype nucl -title "gbBlastn" -taxid_map "$TAX_MAP_FILE"

rm "$TAX_MAP_FILE"
