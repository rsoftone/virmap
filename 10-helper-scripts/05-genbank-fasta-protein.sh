#!/bin/bash
#PBS -l ncpus=48
#PBS -l mem=48gb
#PBS -l walltime=04:00:00
#PBS -l wd
#PBS -j oe
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -v SORTED_GB_ACC_LIST="${SORTED_GB_ACC_LIST}",GENBANKPATH="${GENBANKPATH}" 05-genbank-fasta-protein.sh
##
## Output directory for .fasta file: converted/protein
##
cd "${PBS_O_WORKDIR}"

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
rsync -avP "$SORTED_GB_ACC_LIST" "$MEM_SORTED_GB_ACC_LIST"

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

if command -v parallel >/dev/null 2>/dev/null; then
    printf '%s\0' "$GENBANKPATH/"*.seq.gz | sort -zV |
        xargs -0I'{}' basename '{}' |
        parallel -j"$THREADS" -tI'{}' process {}
else
    if [[ "$THREADS" -gt 1 ]]; then
        echo "[!] You requested/autodetected $THREADS, but parallel was not found in \$PATH."
        echo "[!] Parallel is requierd by this script to use more than one thread,"
        echo "[!] aborting to avoid wasting resources."
        echo -e "\n\$PATH=$PATH"

        exit 1
    fi

    printf '%s\0' "$GENBANKPATH/"*.seq.gz | sort -zV |
        xargs -0I'{}' basename '{}' |
        xargs -tI '{}' sh -c 'process {}'
fi

rm "$MEM_SORTED_GB_ACC_LIST"
