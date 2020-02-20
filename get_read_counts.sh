#!/usr/bin/env bash
# get_read_counts.sh
#
function usage() {
    printf "\nUsage: ./get_read_counts.sh path/to/virmap_output.final.fa /path/to/virmap_input_sequence.fq\n"
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

module load bwa
module load samtools

GENMOE_REF='/scratch/u71/dm2443/extract_unmapped_reads/GCA_000001405.15_GRCh38_full_plus_hs38d1_analysis_set.fna'
PHAGE_REF='/scratch/u71/dm2443/bwa_db/gbphg'
BACT_REF='/scratch/u71/dm2443/bwa_db/gbbct_derep_new'
INPUT="$1"
ORIGINAL_SAMPLE="$2"
THREADS="${PBS_NCPUS:-${NCPUS:-$(nproc)}}"

TMP_DIR=$(mktemp -d -p "$(pwd)")
# trap cleanup INT
# function cleanup() {
#     rm -rf "$TMP_DIR"
# }

function get_unmapped() {
    local name=$1
    local input=$2
    local ref_db=$3

    local tmp_prefix="$TMP_DIR/$name.align"

    set -x
    bwa mem -t "$THREADS" "$ref_db" "$input" |
        samtools view -h -f 4 |
        samtools sort --threads "$THREADS" -o "$tmp_prefix.unmapped.sort.bam"

    samtools fastq "$tmp_prefix.unmapped.sort.bam"
}

function get_mapped() {
    local name=$1
    local input=$2
    local ref_db=$3

    local tmp_prefix="$TMP_DIR/$name.align"

    set -x
    bwa mem -t "$THREADS" "$ref_db" "$input" |
        samtools view -h -F 4 |
        samtools sort --threads "$THREADS" -o "$tmp_prefix.mapped.sort.bam"

    samtools fastq "$tmp_prefix.mapped.sort.bam"
}

# samtools can only accept sequence headers up to 252(?) bytes long, so we'll
# just change them all to be short
perl -pe 'BEGIN{$A=1;} s/^>.*/">SEQUENCE_INDEX_" . $A++/ge' "$ORIGINAL_SAMPLE" >"$TMP_DIR/sanitized_input.fa"

get_unmapped "human" "$TMP_DIR/sanitized_input.fa" "$GENMOE_REF" >"$TMP_DIR/unmapped_1_human.fq"
get_unmapped "phage" "$TMP_DIR/unmapped_1_human.fq" "$PHAGE_REF" >"$TMP_DIR/unmapped_2_phage.fq"
get_unmapped "bact" "$TMP_DIR/unmapped_2_phage.fq" "$BACT_REF" >"$TMP_DIR/unmapped_3_bact.fq"

ln -s "$TMP_DIR/unmapped_3_bact.fq" "$TMP_DIR/unmapped_all.fq"
ln -s "$TMP_DIR/bact.align.unmapped.sort.bam" "$TMP_DIR/unmapped_all.bam"

sample_ref="$TMP_DIR/virmap_final"
bwa index -p "$sample_ref" "$INPUT"
get_mapped "sample" "$TMP_DIR/unmapped_all.fq" "$sample_ref" >"$TMP_DIR/mapped_sample.fq"

samtools view -h -q 1 -F 4 -F 256 "$TMP_DIR/sample.align.mapped.sort.bam" |
    grep -v -e 'XA:Z:' -e 'SA:Z:' |
    samtools view -b >"$TMP_DIR/unique_mapped.bam"

echo "$TMP_DIR"

name_prefix=$(basename "$INPUT")

# extract the sizes reported by virmap
grep '^>' "$INPUT" |
    sed 's/^.*;taxId=\([0-9]*\);.*;size=\([0-9]*\);.*/\1 \2/' |
    sort -k1,1 >"counts.$name_prefix.virmap"

# count the reads after removing human/phage/bact reads
samtools view "$TMP_DIR/sample.align.mapped.sort.bam" | cut -f 3 | sort | uniq -c |
    sed 's/^ *\([0-9]*\).*;taxId=\([0-9]*\);.*;size=\([0-9]*\);.*/\2 \1/' |
    sort -k1,1 >"counts.$name_prefix.unmapped"

# count the reads after removing duplicates
samtools view "$TMP_DIR/unique_mapped.bam" | cut -f 3 | sort | uniq -c |
    sed 's/^ *\([0-9]*\).*;taxId=\([0-9]*\);.*;size=\([0-9]*\);.*/\2 \1/' |
    sort -k1,1 >"counts.$name_prefix.no_dupe"

# join the count files on taxid
{
    echo "taxid virmapSize unmappedCounts withoutSACounts"
    join -a 1 -j 1 -o 1.1,1.2,2.2 "counts.$name_prefix.virmap" "counts.$name_prefix.unmapped" |
        join -a 1 -j 1 -o 1.1,1.2,1.3,2.2 - "counts.$name_prefix.no_dupe" |
        sort -nr -k2,2
} | tr ' ' '\t' >"counts.$name_prefix.all"

if type column >/dev/null; then
    # If column is available, output the counts as a table

    column -t -s $'\t' "counts.$name_prefix.all"
else
    # Otherwise, just dump it out

    cat "counts.$name_prefix.all"
fi

# cleanup
