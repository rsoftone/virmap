## taxaJson.dat generation script
The name is misleading - it is **not** JSON but actually Sereal-encoded, Zstd compressed Perl hash reference built up from NCBI taxonomy files.

### Quickstart

```
./01-construct-taxa.sh
```
 
This script will: 
* download the Taxonomy data from NCBI,
* uncompress it,
* calls 10-construct-taxa.pl to process it.  

The final output is the file: **taxaJson.dat**
