#  Copyright 2020 University of New South Wales
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

import argparse
import logging
import os
import sys
from typing import List

import tax_db
from aggreg_stats_workbook import AggregStatsWorkbook
from sample_results import SampleResults
from util import get_logger

logger = get_logger(__name__)


class AggregateStatsResults(object):
    def __init__(self):
        self.out_filename: str = None
        self.samples: List[SampleResults] = []

    def add_sample_results(self, directory: str):
        logger.info("Loading sample from %r", directory)
        self.samples.append(SampleResults(directory))

    def execute(self):
        assert self.out_filename is not None
        assert self.samples

        aggreg_stats = AggregStatsWorkbook(self.out_filename)
        aggreg_stats.process(self.samples)

    def add_sample_dir(self, samples_dir: str):
        filenames = set(os.listdir(samples_dir))

        for filename in filenames:
            if filename.endswith(".log") and filename[:-4] in filenames:
                self.add_sample_results(os.path.join(samples_dir, filename[:-4]))


def main(args):
    parser = argparse.ArgumentParser()
    exclusive = parser.add_mutually_exclusive_group(required=True)
    exclusive.add_argument('-d', '--samples-dir', type=str, help='Directory containing multiple sample outputs')
    exclusive.add_argument('-s', '--sample', nargs='+', type=str, help='Path to one or more sample output directories')

    parser.add_argument('-t', '--taxonomy', type=str, help='Directory containing taxonomy files (e.g. nodes.dmp)', required=True)
    parser.add_argument('-o', '--output', type=str, help='Filename for output worksheet', required=True)
    parser.add_argument('-p', '--per-sample-output', type=str, help='Directory to output brief logs and misc. info for each sample')
    parser.add_argument('-v', '--verbose', action='store_const', const=True, help='Show DEBUG level log messages')

    parsed = parser.parse_args(args)
    if parsed.verbose:
        from util import console_handler
        console_handler.setLevel(logging.DEBUG)

    logger.debug('Parsed args: %r', parsed)

    agg = AggregateStatsResults()
    agg.out_filename = os.path.abspath(parsed.output)

    output_folder = os.path.dirname(agg.out_filename)
    if not os.path.exists(output_folder):
        raise ValueError(f"Destination folder {output_folder!r} doesn't exist!")

    tax_db.load_tax_tree(parsed.taxonomy)

    if parsed.samples_dir:
        agg.add_sample_dir(parsed.samples_dir)
    else:
        for sample in parsed.sample:
            agg.add_sample_results(sample)

    agg.execute()

    if parsed.per_sample_output:
        for sample in agg.samples:
            sample.save(os.path.join(parsed.per_sample_output, sample.run_name))


if __name__ == '__main__':
    main(sys.argv[1:])
