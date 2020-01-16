#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"

function find_activate() {
    if [[ -e "activate.sh" ]]; then
        readlink -e "activate.sh"
        return 0
    elif [[ -n "${INSTALL_DIR:-}" ]] && [[ -e "$INSTALL_DIR/activate.sh" ]]; then
        readlink -e "$INSTALL_DIR/activate.sh"
        return 0
    elif [[ -e "$SCRIPT_DIR/activate.sh" ]]; then
        readlink -e "$SCRIPT_DIR/activate.sh"
        return 0
    fi

    echo >&2 "[!] Failed to find virmap activation wrapper script 'activate.sh'."
    echo >&2 "[!] Copy this script to or run this script from the directory containing 'activate.sh'."
    exit 1
}

function find_settings() {
    if [[ -e "virmap_config.sh" ]]; then
        readlink -e "virmap_config.sh"
    elif [[ -n "${INSTALL_DIR:-}" ]] && [[ -e "$INSTALL_DIR/virmap_config.sh" ]]; then
        readlink -e "$INSTALL_DIR/virmap_config.sh"
    elif [[ -e "$SCRIPT_DIR/virmap_config.sh" ]]; then
        readlink -e "$SCRIPT_DIR/virmap_config.sh"
    elif [[ -n "${INSTALL_DIR:-}" ]]; then
        cat >"$INSTALL_DIR/virmap_config.sh" <<EOF
## Config file for virmap_wrapper.sh
##
## Uncomment and edit lines of interest

## File path, used as the value for the --gbBlastx parameter
# GB_BLASTX=/path/to/gbblastx.dmnd

## Partial file path, used as the value for the --gbBlastn parameter
# GB_BLASTN=/path/to/gbBlastn/gbBlastn

## Folder path, used as the value for the --virBbmap parameter
# VIR_BBMAP=/path/to/virBbmap

## File path, used as the value for the --virDmnd parameter
# VIR_DMND=/path/to/virdiamond.dmnd

## File path, used as the value for the --taxaJson parameter
# TAXA_JSON=/path/to/taxaJson.dat
EOF
        echo -e "\n[ ] A template config file has been copied to $(printf "%q" "$INSTALL_DIR/virmap_config.sh")\n" >&2
        readlink -e "$INSTALL_DIR/virmap_config.sh"
    fi
}

function verify_exists_file() {
    if [[ ! -f "$2" ]]; then
        if [[ -d "$2" ]]; then
            echo >&2 "[!] $1: $(printf "%q" "$2") is a directory!"
            exit 1
        else
            echo >&2 "[!] $1: $(printf "%q" "$2") does not exist!"
            exit 1
        fi
    fi
}

function verify_exists_dir() {
    if [[ ! -d "$2" ]]; then
        if [[ -f "$2" ]]; then
            echo >&2 "[!] $1: $(printf "%q" "$2") is a file!"
            exit 1
        else
            echo >&2 "[!] $1: $(printf "%q" "$2") does not exist!"
            exit 1
        fi
    fi
}

function verify_dmnd() {
    verify_exists_file "$1" "$2"
    if ! diamond dbinfo --db "$2" >/dev/null 2>/dev/null; then
        echo >&2 "[!] $1 invalid database: $(printf "%q" "$2")"
        diamond dbinfo --db "$2" >&2
        exit 1
    fi
}

function verify_blastn() {
    if ! find "$2".*.n?? -quit 2>/dev/null; then
        echo >&2 "[!] $1 invalid path to blastn database: $(printf "%q" "$2")"
        echo >&2 "[!] e.g. for a path such as /path/to/191205-gbBlastn.00.nhr"
        echo >&2 "[!]      use /path/to/191205-gbBlastn as the parameter"
        exit 1
    fi
}

function load_settings() {
    local settings_path

    settings_path=$(find_settings)
    if [[ -z "$settings_path" ]]; then
        return 0
    fi

    echo "[ ] Loading settings from: $(printf "%q" "$settings_path")"

    source "$settings_path"
}

function args_has_flag() {
    for i in "${ORIGINAL_ARGS[@]}"; do
        if [ "$i" == "$1" ]; then
            return 0
        fi
    done

    return 1
}

###################
### Script body ###
###################

activate_script=$(find_activate)
source "$activate_script"

load_settings

# Copy the original args - also used by args_has_flag()
ORIGINAL_ARGS=("$@")

# Parse out some of the Virmap args we'd like to check
while [ $# -ge 1 ]; do
    case "$1" in
    --sampleName)
        sample_name="${2:-}"
        shift
        ;;
    --gbBlastx)
        GB_BLASTX="${2:-}"
        shift
        ;;
    --gbBlastn)
        GB_BLASTN="${2:-}"
        shift
        ;;
    --virBbmap)
        VIR_BBMAP="${2:-}"
        shift
        ;;
    --virDmnd)
        VIR_DMND="${2:-}"
        shift
        ;;
    --taxaJson)
        TAXA_JSON="${2:-}"
        shift
        ;;
    esac

    shift
done

if [[ -z "${sample_name:-}" ]]; then
    echo >&2 "[!] Missing --sampleName parameter"
    exit 1
fi

UNIXTIME=$(date +%s)
THREADS="${PBS_NCPUS:-${NCPUS:-$(nproc)}}"
NAME=$(echo "$sample_name" | tr ' ' '_' | tr -d '\\/')
JOB_NAME="${NAME}_T$THREADS"
RUN_OUTPUT="$(readlink -f "${JOB_NAME}_${UNIXTIME}")"
RUN_TMP="$(readlink -f "${JOB_NAME}_${UNIXTIME}_tmp")"

# Check settings for sanity
extra_args=()
if [[ -n "${GB_BLASTX:-}" ]]; then
    verify_dmnd "GB_BLASTX" "$GB_BLASTX"
    if ! args_has_flag "gbBlastx"; then
        extra_args+=("--gbBlastx" "$GB_BLASTX")
    fi
fi
if [[ -n "${GB_BLASTN:-}" ]]; then
    verify_blastn "GB_BLASTN" "$GB_BLASTN"
    if ! args_has_flag "gbBlastn"; then
        extra_args+=("--gbBlastn" "$GB_BLASTN")
    fi
fi
if [[ -n "${VIR_BBMAP:-}" ]]; then
    verify_exists_dir "VIR_BBMAP" "$VIR_BBMAP"
    if ! args_has_flag "virBbmap"; then
        extra_args+=("--virBbmap" "$VIR_BBMAP")
    fi
fi
if [[ -n "${VIR_DMND:-}" ]]; then
    verify_dmnd "VIR_DMND" "$VIR_DMND"
    if ! args_has_flag "virDmnd"; then
        extra_args+=("--virDmnd" "$VIR_DMND")
    fi
fi
if [[ -n "${TAXA_JSON:-}" ]]; then
    verify_exists_file "TAXA_JSON" "$TAXA_JSON"
    if ! args_has_flag "taxaJson"; then
        extra_args+=("--taxaJson" "$TAXA_JSON")
    fi
fi

# Add some extra flags if they weren't specified by the user
if ! args_has_flag "--outputDir"; then
    extra_args+=("--outputDir" "$RUN_OUTPUT")
fi
if ! args_has_flag "--tmp"; then
    mkdir -p "$RUN_TMP"
    extra_args+=("--tmp" "$RUN_TMP")
fi
if ! args_has_flag "--threads"; then
    extra_args+=("--threads" "$THREADS")
fi

export OMP_NUM_THREADS=$THREADS

Virmap.pl \
    "${extra_args[@]}" \
    "${ORIGINAL_ARGS[@]}"
