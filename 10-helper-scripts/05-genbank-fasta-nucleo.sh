#!/usr/bin/env bash
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
#PBS -l ncpus=1
#PBS -l mem=1gb
#PBS -l walltime=04:00:00
#PBS -l wd
#PBS -j oe
#
# 05-genbank-fasta-nucleo.sh
#
function usage() {
    printf "\nUsage: ./05-genbank-fasta-nucleo.sh path/to/sorted/GbAccList path/to/genbank/divisions [threads]\n"
}
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -v SORTED_GB_ACC_LIST="${SORTED_GB_ACC_LIST}" -v GENBANKPATH="${GENBANKPATH}" 05-genbank-fasta-nucleo.sh
##
## Output directory for .fasta file: converted/nucleotide
##

set -o errexit
set -o nounset
set -o pipefail

if [[ $# -eq 0 ]] && { [[ -z "${SORTED_GB_ACC_LIST:-}" ]] || [[ -z "${GENBANKPATH:-}" ]]; }; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"
PREFPATH=converted/nucleotide
mkdir -p "$PREFPATH"

THREADS="${3:-${PBS_NCPUS:-${NCPUS:-$(nproc)}}}"

if [[ -z "${SORTED_GB_ACC_LIST:-}" ]] || [[ -z "${GENBANKPATH:-}" ]]; then
    SORTED_GB_ACC_LIST="$1"
    GENBANKPATH="$2"
fi

function process() {
    local div_file=$GENBANKPATH/$1
    local out_file=$PREFPATH/$(echo "$1" | sed "s=.seq.gz$=.fasta=g")

    if [[ -s "${out_file}" ]]; then
        echo "Skipping $1 as it appears to have been processed already"
        return 0
    fi

    set -e
    perl "$SCRIPT_DIR/03-hash.pl" "$SORTED_GB_ACC_LIST" <(pigz -dc "$div_file") >"${out_file}.part"
    mv "${out_file}.part" "${out_file}"
}
export -f process
export PREFPATH GENBANKPATH SORTED_GB_ACC_LIST SCRIPT_DIR

printf '%s\0' "$GENBANKPATH/"*.seq.gz | sort -zV |
    xargs -0I'{}' basename '{}' |
    parallel -j"$THREADS" -tI'{}' process {}
