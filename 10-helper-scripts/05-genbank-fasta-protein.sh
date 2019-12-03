#!/bin/bash
#PBS -l nodes=1:ppn=2
#PBS -l mem=250gb
#PBS -l walltime=03:00:00
#
# Assumes you have run the script in the previous section Part 3: Genbank division download
#
## Expected form of qsub:
##
## qsub -N "${PREFIXDB}"-protein -J 1-$(find "${GENBANKPATH}" -type f -name "${PREFIXDB}"*.seq|wc -l) -v PREFIXDB="${PREFIXDB}" 05-genbank-fasta-protein.sh
##
## Output directory for .fasta file: converted/protein
##
cd "${PBS_O_WORKDIR}"

PREFPATH=converted/protein
GENBANKPATH=genbank-ref
TMPW=$(mktemp -d)

GBIN=$(find $GENBANKPATH -type f -name "${PREFIXDB}*.seq" | sort -n | sed -n "${PBS_ARRAY_INDEX}p")
SEQOUT=$(echo $GBIN | sed "s=$GENBANKPATH=$PREFPATH=g" | sed "s=.seq$=.fasta=g")

echo "${PBS_ARRAY_INDEX}":...GenBank Division: $PREFIXDB
echo "${PBS_ARRAY_INDEX}":...Input GenBank flat-file: $GBIN
echo "${PBS_ARRAY_INDEX}":...Output FASTA: $SEQOUT

time ./03-prot-hash.pl <(cat part00 part01 part02 part03 part04 part05 part06 part07 part08 part09 part10 part11 part12 part13 part14 part15 part16 part17) "${GBIN}" >"${TMPW}/${PBS_ARRAY_INDEX}.fasta"

#
# Now copy results from TMP directory to final output location...
#

cp "${TMPW}/${PBS_ARRAY_INDEX}.fasta" "${SEQOUT}"
rm -rf "${TMPW}"
