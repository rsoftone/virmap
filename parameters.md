# VirMAP Parameters

Parameter            | Type   | Required              | Notes
-------------------- | ------ | --------------------- | -----------------------------------------------------------------------------------------------------------------------------------------------------
`--interleaved`      | Path   |                       | Path to input file containing interleaved forward and reverse reads, _may be specified multiple times_
`--readF`            | Path   |                       | Path to input file containing forward reads, must have an accompanying `--readR` parameter in the same order, _may be specified multiple times_
`--readR`            | Path   |                       | Path to input file containing reverse reads, must have an accompanying `--readF` parameter in the same order, _may be specified multiple times_
`--readUnpaired`     | Path   |                       | Path to input file containing unpaired reads, _may be specified multiple times_
`--outputDir`        | Path   | Yes                   | Path to the output folder, **must not exist**
`--sampleName`       | String | Yes                   | Used as a prefix for filenames in the pipeline
`--gbBlastx`         | Path   | Unless `noTaxaDep`¹   | Amino acid Genbank `diamond` database
`--gbBlastn`         | Path   | Unless `noTaxaDep`¹   | Nucleotide Genbank `blast` database
`--virBbmap`         | Path   | Unless `--noNucMap`   | Nucleotide Virus `bbmap` database - see [10-helper-scripts](./10-helper-scripts/README.md)
`--virDmnd`          | Path   | Unless `--noAaMap`    | Amino acid Virus `diamond` database - see [10-helper-scripts](./10-helper-scripts/README.md)
`--taxaJson`         | Path   | Unless `noTaxaDep`¹   | Zstd compressed Sereal encoded perl hash - see [10-helper-scripts](./10-helper-scripts/README.md)
`--fasta`            | Flag   | No (default: `fastq`) | Indicates input files are in FASTA format (as opposed to FASTQ)
`--threads`          | Number | No (default: `4`)     | A value less than 4 is overridden to 4
`--tmpdir`           | Path   | Sometimes             | If not specified, `$TMPDIR` from the environment is used and will abort if unset
`--bbMapLimit`       | Number | No (default: `4`)     | Maximum concurrent (global?) `bbmap.sh` processes
`--bigRam`           | Flag   |                       | Launches tools with parameters targeting 100GB ram usage
`--both`             | Flag   |                       | Use both `tadpole.sh` and `megahit` for assembly
`--hugeRam`          | Flag   |                       | Launches tools with parameters targeting up to 1.2TB ram usage
`--improveTimeLimit` | Number | No (default: `36000`) | Time limit in seconds for `improveWrapper.pl` to converge
`--infoFloor`        | Number | No (default: `300`)   | Minimum virus score for use in `determineTaxonomy.pl`
`--keepTemp`         | Flag   |                       | Don't delete temporary files
`--krakenDb`         | Path   | If `--krakenFilter`   | Path to the `kraken2` database
`--krakenFilter`     | Flag   |                       | Run `kraken2` and `krakenFilter.pl` following assembly
`--loose`            | Flag   |                       | Lowers minimum identity percent for read mapping. Mutually exclusive with `--strict`
`--noAaMap`          | Flag   |                       | Skips mapping to protein database i.e. `diamond blastx`. `--virDmnd` may be omitted with this option
`--noAssembly`       | Flag   |                       | Skip all assembly steps, takes precedence over other assembly options
`--noCorrection`     | Flag   |                       | Skip kmer correction during tadpole sensitive assmebly, only applicaple when paired with the --sensitive option
`--noEntropy`        | Flag   |                       | Skip entropy-based contitg filtering, overridden if taxonomy based filtering is enabledu
`--noFilter`         | Flag   |                       | Skip taxonomy-based contig filtering
`--noIterImp`        | Flag   |                       | Skips iterative contig improvement i.e. `improveWrapper.pl`
`--noMerge`          | Flag   |                       | Skip contig merging, only considered if iterative improvement (`--noIterImp`) is also disabled
`--noNormalize`      | Flag   |                       | Skips read normalization i.e. `bbnorm.sh` / `normalize-by-median.py`
`--noNucMap`         | Flag   |                       | Skips mapping to nucleotide database i.e. `bbmap.sh`. `--virBbmap` may be omitted with this option
`--sensitive`        | Flag   |                       | Uses additional kmer steps and lowers kmer coverage requirements during assembly
`--skipTaxonomy`     | Flag   |                       | Skips taxonomic classification
`--strict`           | Flag   |                       | Raises minimum identity percent for read mapping. Mutually exclusive with `--loose`
`--useBbnorm`        | Flag   |                       | Use `bbnorm.sh` instead of `normalize-by-median.py` for normalization
`--useMegahit`       | Flag   |                       | Use `megahit` for assembly instead of `tadpole.sh`
`--whiteList`        | Path   |                       | Path to file containing list of taxIds (separated by new lines) which will be exempt from `determineTaxonomy.pl` filtering, along with their children

1 . `noTaxaDep` is the presence of `--skipTaxonomy`, `--noFilter` and `--noIterImp`

Also see [VirMAP Supplementary Data 14](https://www.nature.com/articles/s41467-018-05658-8#MOESM14) for a subset of parameter descriptions.
