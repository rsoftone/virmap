#!/usr/bin/env bash
# 80-construct-kraken2.sh
#
function usage() {
    printf "\nUsage: ./80-construct-kraken2.sh path/to/genbank/nucleotide/fasta [outputLocation] [threads]\n"
}
#
# Description:
#     Helper script for building a kraken2 database from FASTA formatted
#     Genbank Nucleotide divisions.
#
# Also accepts parameters via GENBANK_NUC, DEST_DB, NCPUS environment variables

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

GENBANK_NUC="${1:-${GENBANK_NUC:-}}"
DEST_DB="${2:-${DEST_DB:-krakenDb}}"
THREADS="${3:-${PBS_NCPUS:-${NCPUS:-$(nproc)}}}"

if [[ -z "$GENBANK_NUC" ]] || [[ -z "$DEST_DB" ]]; then
    usage
    exit 0
fi

if [[ -z "${3:-}" ]]; then
    echo "[+] Auto detected threads=$THREADS"
fi

if ! ls "$GENBANK_NUC" >/dev/null; then
    exit 1
fi

# OMP_NUM_THREADS is set to 1 in /etc/profile.d/nci.sh on Gadi, which prevents
# kraken2-build from using multiple threads
unset OMP_NUM_THREADS

if [[ ! -d "$DEST_DB/taxonomy" ]]; then
    echo "[+] Downloading taxonomy data for kraken2.."
    echo "[+] If this fails (e.g. due to no network access in job), run the following command elsewhere:"
    printf "kraken2-build --download-taxonomy --db %q\n" "$(readlink -f "$DEST_DB")"
    kraken2-build --download-taxonomy --db "$DEST_DB"
else
    printf "[+] %q already exists, assuming taxonomy is fully downloaded.\n" "$(readlink -f "$DEST_DB/taxonomy")"
fi

if command -v parallel >/dev/null 2>/dev/null; then
    echo "[+] Using parallel to speed up library construction"
    printf '%s\0' "$GENBANK_NUC/"*.fasta | sort -zV |
        parallel -j"$THREADS" -0tI '{}' kraken2-build --db "$DEST_DB" --add-to-library '{}'
else
    echo "[-] parallel utility not found, library construction is essentially single threaded!"
    printf '%s\0' "$GENBANK_NUC/"*.fasta | sort -zV |
        xargs -0tI '{}' kraken2-build --db "$DEST_DB" --add-to-library '{}'
fi

kraken2-build --build --db "$DEST_DB" --threads "$THREADS"

echo "[+] The following command will remove files no longer necessary from the database:"
printf "kraken2-build --clean --db %q\n" "$(readlink -f "$DEST_DB")"
