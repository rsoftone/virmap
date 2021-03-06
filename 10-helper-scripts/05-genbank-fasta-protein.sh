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
#PBS -l ncpus=48
#PBS -l mem=48gb
#PBS -l walltime=04:00:00
#PBS -l wd
#PBS -j oe
#
# 05-genbank-fasta-protein.sh
#
function usage() {
    printf "\nUsage: ./05-genbank-fasta-protein.sh path/to/sorted/GbAccList path/to/genbank/divisions [threads]\n"
}
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -v SORTED_GB_ACC_LIST="${SORTED_GB_ACC_LIST}",GENBANKPATH="${GENBANKPATH}" 05-genbank-fasta-protein.sh
##
## Output directory for .fasta file: converted/protein
##

set -o errexit
set -o nounset
set -o pipefail

if [[ $# -eq 0 ]] && { [[ -z "${SORTED_GB_ACC_LIST:-}" ]] || [[ -z "${GENBANKPATH:-}" ]]; }; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"
PREFPATH=converted/protein
mkdir -p "$PREFPATH"

THREADS="${3:-${PBS_NCPUS:-${NCPUS:-$(nproc)}}}"

if [[ -z "${SORTED_GB_ACC_LIST:-}" ]] || [[ -z "${GENBANKPATH:-}" ]]; then
    SORTED_GB_ACC_LIST="$1"
    GENBANKPATH="$2"
fi

# Copy the GB-Acc mapping to ram as we need to search the entire file for each entry
MEM_SORTED_GB_ACC_LIST=$(mktemp -up /dev/shm)
if [[ "$SORTED_GB_ACC_LIST" = *.gz ]]; then
    echo "Extracting $SORTED_GB_ACC_LIST into $MEM_SORTED_GB_ACC_LIST"
    pigz -dcp "$THREADS" "$SORTED_GB_ACC_LIST" > "$MEM_SORTED_GB_ACC_LIST"
else
    rsync -avP "$SORTED_GB_ACC_LIST" "$MEM_SORTED_GB_ACC_LIST"
fi

function process() {
    local div_file=$GENBANKPATH/$1
    local out_file=$PREFPATH/$(echo "$1" | sed "s=.seq.gz$=.fasta=g")

    if [[ -s "${out_file}" ]]; then
        echo "Skipping $1 as it appears to have been processed already"
        return 0
    fi

    set -e
    perl "$SCRIPT_DIR/03-prot-hash.pl" "$MEM_SORTED_GB_ACC_LIST" <(pigz -dc "$div_file") >"${out_file}.part"
    mv "${out_file}.part" "${out_file}"
}
export -f process
export PREFPATH GENBANKPATH MEM_SORTED_GB_ACC_LIST SCRIPT_DIR

# sort by filesize descending, ideally would sort on head -n 8 | tail -n 1 | tr -s ' ' | cut -d ' ' -f 7
function get_gb_divs() {
    NUM_GROUPS=${NUM_GROUPS:-1}
    GROUP_INDEX=${GROUP_INDEX:-0}

    gzip -l "$GENBANKPATH/"*.seq.gz | tail -n +2 | head -n -1 |
        sort -rnk 2,2 | tr -s ' ' | cut -d ' ' -f 5 | sed 's/$/.gz/' |
        xargs -I'{}' basename '{}' |
        awk "(NR + $GROUP_INDEX) % $NUM_GROUPS == 0"
}

if [[ -n "${NUM_GROUPS:-}" ]]; then
    echo "[ ] Group ${GROUP_INDEX:-0} of ${NUM_GROUPS:-1}"
fi

if command -v parallel >/dev/null 2>/dev/null; then
    get_gb_divs |
        parallel -j"$THREADS" -tI'{}' process {}
else
    if [[ "$THREADS" -gt 1 ]]; then
        echo "[!] You requested/autodetected $THREADS, but parallel was not found in \$PATH."
        echo "[!] Parallel is requierd by this script to use more than one thread,"
        echo "[!] aborting to avoid wasting resources."
        echo -e "\n\$PATH=$PATH"

        exit 1
    fi

    get_gb_divs |
        xargs -tI '{}' sh -c 'process {}'
fi

rm "$MEM_SORTED_GB_ACC_LIST"
echo "Finished!"
