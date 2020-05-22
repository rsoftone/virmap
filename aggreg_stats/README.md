# Aggreg Stats

## Requirements

* `xlsxwriter` python library
    * `pip install xlsxwriter`

    Or

    * `conda install xlsxwriter`
    
* Extracted GenBank taxonomy database

## Usage

```bash
usage: main.py [-h] (-d SAMPLES_DIR | -s SAMPLE [SAMPLE ...]) -t TAXONOMY -o OUTPUT [-p PER_SAMPLE_OUTPUT] [-v]

optional arguments:
  -h, --help            show this help message and exit
  -d SAMPLES_DIR, --samples-dir SAMPLES_DIR
                        Directory containing multiple sample outputs
  -s SAMPLE [SAMPLE ...], --sample SAMPLE [SAMPLE ...]
                        Path to one or more sample output directories
  -t TAXONOMY, --taxonomy TAXONOMY
                        Directory containing taxonomy files (e.g. nodes.dmp)
  -o OUTPUT, --output OUTPUT
                        Filename for output worksheet
  -p PER_SAMPLE_OUTPUT, --per-sample-output PER_SAMPLE_OUTPUT
                        Directory to output brief logs and misc. info for each sample
  -v, --verbose         Show DEBUG level log messages
```

The `p` / `--per-sample-output` flag can be specified to copy:

* Log info from VirMap
* The results
* A flame graph `flame.html` showing a more detailed breakdown of the runtime
* `output_taxid_counts.txt` containing the taxonomy for each entry in the output from VirMap
* `errors.txt` containing any lines in the logs flagged as an error or warning 

### Example

Where `/path/to/results/directory` contains one or more runs
```bash
python main.py \
    -t /path/to/taxonomy/database \
    -o output.xlsx \
    -d /path/to/results/directory
```

Where `/path/to/results/directory/run_X_TYY_ZZZ` are arbitrarily many runs

**N.B.** `-s` need only be specified once

```bash
python main.py \
    -t /path/to/taxonomy/database \
    -o output.xlsx \
    -s /path/to/results/directory/run_some_sample_T12_2222222222 \
       /path/to/results/directory/run_another_sample_T24_333333333 \
       /path/to/results/directory/run_other_sample_T48_444444444
```
