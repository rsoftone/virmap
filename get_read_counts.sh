#!/usr/bin/env bash
# get_read_counts.sh
#
function usage() {
    cat <<EOF >&2
Usage: ./get_read_counts.sh -g human_genome_bwa -p phage_bwa -b bacteria_bwa virmap_output.final.fa virmap_input_sequence.fq

-g, --genome BWA_REF    Path prefix to the human genome bwa index
-p, --phage BWA_REF     Path prefix to the gbphage bwa index
-b, --bacteria BWA_REF  Path prefix to the gbbact bwa index
-t, --threads T         (Optional) use T threads
-k, --keep              Don't delete the temporary directory used

EOF
}
#
# Description:
#     Obtain counts of reads from virmap output in the original input sequence

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

if ! type bwa >/dev/null; then
    echo >&2 "[!] bwa command not found"
    exit 1
fi
if ! type samtools >/dev/null; then
    echo >&2 "[!] samtools command not found"
    exit 1
fi

function cleanup() {
    rm -rf "$TMP_DIR"
}

function check_is_bwa_index() {
    local display_name="$1"
    local bwa_prefix="$2"

    for file in "$bwa_prefix".{amb,ann,bwt,pac}; do
        if [[ ! -f "$file" ]]; then
            echo >&2 "[!] $display_name BWA index doesn't look right"
            find "$file"
            exit 1
        fi
    done
}

function get_unmapped() {
    local name=$1
    local input=$2
    local ref_db=$3

    local tmp_prefix="$TMP_DIR/$name.align"

    echo >&2 "[ ] Extracting reads which don't map to $name"

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

    echo >&2 "[ ] Extracting reads mapped to $name"

    bwa mem -t "$THREADS" "$ref_db" "$input" |
        samtools view -h -F 4 |
        samtools sort --threads "$THREADS" -o "$tmp_prefix.mapped.sort.bam"

    samtools fastq "$tmp_prefix.mapped.sort.bam"
}

###################
### Script body ###
###################

OPTIONS=g:p:b:t:
LONGOPTIONS=genome:,phage:,bacteria:,threads:

PARSED=$(getopt --options=${OPTIONS} --longoptions=${LONGOPTIONS} --name "$0" -- "$@")

if [[ $? -ne 0 ]]; then
    usage
    exit 2
fi

eval set -- "${PARSED}"

# non option arguments
if [[ $# -eq 1 ]]; then
    usage
    exit 4
fi

while true; do
    case "$1" in
    -g | --genome)
        GENMOE_REF="$2"
        shift 2
        ;;
    -p | --phage)
        PHAGE_REF="$2"
        shift 2
        ;;
    -b | --bacteria)
        BACT_REF="$2"
        shift 2
        ;;
    -t | --threads)
        THREADS="$2"
        shift 2
        ;;
    -k | --keep)
        KEEP=1
        shift 1
        ;;
    --)
        shift
        break
        ;;
    *)
        if [ -z "$1" ]; then break; else
            echo >&2 "[!] '$1' is not a valid option"
            exit 3
        fi
        ;;
    esac
done

INPUT="${1:-}"
ORIGINAL_SAMPLE="${2:-}"

if [[ $# -gt 2 ]]; then
    echo >&2 "[!] ${*:3} invalid option(s)"
    exit 4
fi

if [[ -z "${GENMOE_REF:-}" ]]; then
    echo >&2 "[!] GENMOE_REF is missing, please specify with -g or --genome"
    exit 1
fi

if [[ -z "${PHAGE_REF:-}" ]]; then
    echo >&2 "[!] PHAGE_REF is missing, please specify with -p or --phage"
    exit 1
fi

if [[ -z "${BACT_REF:-}" ]]; then
    echo >&2 "[!] BACT_REF is missing, please specify with -b or --bacteria"
    exit 1
fi

if [[ -z "$INPUT" ]]; then
    echo >&2 "[!] Positional argument virmap_output is missing"
    exit 1
fi

if [[ -z "$ORIGINAL_SAMPLE" ]]; then
    echo >&2 "[!] Positional argument original_sample is missing"
    exit 1
fi

check_is_bwa_index "Human genome" "$GENMOE_REF"
check_is_bwa_index "Phage" "$PHAGE_REF"
check_is_bwa_index "Bacteria" "$BACT_REF"

THREADS="${THREADS:-${PBS_NCPUS:-${NCPUS:-$(nproc)}}}"
TMP_DIR=$(mktemp -d)
echo "[ ] Using $(printf "%q\n" "$TMP_DIR") as temp dir"

if [[ "${KEEP:-}" != 1 ]]; then
    trap cleanup INT
fi

# samtools can only accept sequence headers up to 252(?) bytes long, so we'll
# just change them all to be short
perl -pe 'BEGIN{$A=1;} s/^>.*/">SEQUENCE_INDEX_" . $A++/ge' "$ORIGINAL_SAMPLE" | gzip -ck9 >"$TMP_DIR/sanitized_input.fq.gz"

get_unmapped "human" "$TMP_DIR/sanitized_input.fq.gz" "$GENMOE_REF" >"$TMP_DIR/unmapped_1_human.fq.gz"
get_unmapped "phage" "$TMP_DIR/unmapped_1_human.fq.gz" "$PHAGE_REF" >"$TMP_DIR/unmapped_2_phage.fq.gz"
get_unmapped "bact" "$TMP_DIR/unmapped_2_phage.fq.gz" "$BACT_REF" >"$TMP_DIR/unmapped_3_bact.fq.gz"

ln -s "$TMP_DIR/unmapped_3_bact.fq.gz" "$TMP_DIR/unmapped_all.fq.gz"
ln -s "$TMP_DIR/bact.align.unmapped.sort.bam" "$TMP_DIR/unmapped_all.bam"

sample_ref="$TMP_DIR/virmap_final"
bwa index -p "$sample_ref" "$INPUT"
get_mapped "sample" "$TMP_DIR/unmapped_all.fq.gz" "$sample_ref" >"$TMP_DIR/mapped_sample.fq.gz"

samtools view -h -q 1 -F 4 -F 256 "$TMP_DIR/sample.align.mapped.sort.bam" |
    grep -v -e 'XA:Z:' -e 'SA:Z:' |
    samtools view -b >"$TMP_DIR/unique_mapped.bam"

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

if [[ "${KEEP:-}" != 1 ]]; then
    cleanup
fi
