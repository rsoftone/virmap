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
import itertools
import os
import re
import shutil
import subprocess
from functools import cached_property
from typing import List, Optional, Set, Tuple

from analyse_times import Node, build_timing_tree, dump_timing_tree
from constants import PERL_DIE_MSGS, PERL_WARNINGS, PAT_TAX_ID, PAT_TAG, PAT_TIME, TIME_CATEGORIES
from tax_db import resolve_taxid
from util import get_logger

PAT_PBS_LOGFILE = re.compile(r"^.*\.o\d+$")
PAT_VIRMAP_ARGS_OUTPUT = re.compile(r"Virmap called with: .*--outputDir ([^\s]+)")

logger = get_logger(__name__)


def find_name(folder):
    for fn in os.listdir(folder):
        if fn.endswith(".log"):
            return fn[:-4]

    return None


class VirmapOutputEntry(object):
    def __init__(self, line: str, tax_match):
        self.flags: Set[str] = set(PAT_TAG.findall(line))
        self.tax_id: int = int(tax_match.group(1))
        self.tax_size: int = int(tax_match.group(2))
        self.taxonomy: List[str] = resolve_taxid(self.tax_id).split(' > ')

    def __repr__(self) -> str:
        return f'VirmapOutputEntry(tax_id={self.tax_id}, tax_size={self.tax_size}, flags={self.flags}, taxonomy={self.taxonomy})'


class SampleResults(object):
    def __init__(self, base_dir: str):
        assert base_dir is not None
        assert os.path.exists(base_dir)

        self.base_dir = os.path.abspath(base_dir)
        logger.debug(self.base_dir)

        self.run_name = os.path.basename(base_dir)
        logger.debug(f'  self.run_name={self.run_name}')
        self.target = self.base_dir
        self.target_tmp = f"{self.base_dir}_tmp"

        self.name = find_name(self.target)
        logger.debug(f'  self.name={self.name}')
        if self.name is None:
            raise ValueError(f"Failed to find sample name for directory {self.base_dir!r}")

        self.prefix = os.path.join(self.target, self.name)
        logger.debug(f'  self.prefix={self.prefix}')
        self.tmp_prefix = os.path.join(self.target_tmp, self.name)
        logger.debug(f'  self.tmp_prefix={self.tmp_prefix}')
        self.final_fa_filename = os.path.join(self.base_dir, f"{self.name}.final.fa")
        logger.debug(f'  self.final_fa_filename={self.final_fa_filename}')

        logger.debug(f'  self.pbs_log_filename={self.pbs_log_filename}')
        logger.debug(f'  self.simple_timing_info={self.simple_timing_info}')

    def save(self, dest_dir: str):
        logger.info("Saving extra info for %r", self.run_name)

        os.makedirs(dest_dir, exist_ok=True)

        # self.graph_cmd_io(self.pbs_log_fn)

        self._copy_log_files(dest_dir)

        dump_timing_tree(dest_dir, self)

        with open(os.path.join(dest_dir, f"errors.txt"), "w") as f:
            f.write('\n'.join(self.warnings_and_errors))

        with open(os.path.join(dest_dir, "output_taxid_counts.txt"), "w") as f:
            for entry in sorted(self.final_output, key=lambda x: x.tax_size, reverse=True):
                f.write(f"taxid={entry.tax_id}, size={entry.tax_size} | {' > '.join(entry.taxonomy)}\n")

    @cached_property
    def pbs_log_filename(self) -> Optional[str]:
        parent_dir = os.path.join(self.base_dir, os.pardir)

        # prefer the log file produced by virmap_wrapper.sh
        wrapper_log_fn = os.path.join(parent_dir, self.run_name + ".log")
        if os.path.exists(wrapper_log_fn):
            return os.path.abspath(wrapper_log_fn)

        # fallback to searching the parent directory for files that look like pbs log filenames
        for fn in os.listdir(parent_dir):
            fn = os.path.join(parent_dir, fn)
            if not os.path.isfile(fn) or not PAT_PBS_LOGFILE.match(fn):
                continue

            # read the first 8KiB of the potential log file
            with open(fn, "r") as f:
                log_data = f.read(8192)

            log_output = PAT_VIRMAP_ARGS_OUTPUT.search(log_data)
            if not log_output:
                continue

            # ensure this log file references this run
            if os.path.basename(log_output.group(1)) == self.run_name:
                # TODO
                # shutil.copy(fn, self.out_dir)

                return fn

        logger.warning(f"Failed to find pbs log filename or virmap_wrapper.sh log file for {self.base_dir!r}")

    @property
    def virmap_log_filename(self) -> str:
        return os.path.join(self.base_dir, self.name + '.log')

    @cached_property
    def detailed_timing_info(self) -> Node:
        return build_timing_tree(self)

    @cached_property
    def simple_timing_info(self) -> Tuple[List[Optional[float]], List[Optional[float]], List[Optional[float]]]:
        # Extract times
        walltimes = [None for _ in TIME_CATEGORIES]
        cputimes = [None for _ in TIME_CATEGORIES]
        cpuratios = [None for _ in TIME_CATEGORIES]

        with open(self.virmap_log_filename, "r") as f:
            for match in PAT_TIME.finditer(f.read()):
                index = TIME_CATEGORIES.index(match.group(1))

                walltimes[index] = float(match.group(2))
                cputimes[index] = float(match.group(3))
                cpuratios[index] = float(match.group(4))

        return walltimes, cputimes, cpuratios

    @cached_property
    def warnings_and_errors(self) -> List[str]:
        target_files = [self.pbs_log_filename] if self.pbs_log_filename else []
        for dirpath, dirnames, filenames in itertools.chain(
                os.walk(self.target), os.walk(self.target_tmp)
        ):
            for fn in filenames:
                fn = os.path.join(dirpath, fn)

                if fn.rsplit(".", 1)[-1] in {"err", "txt", "log"}:
                    target_files.append(fn)

        # # Dump the same results with matches highlighted to the terminal
        # subprocess.check_call([
        #     "grep",
        #     "--color",
        #     "-nF",
        #     "\n".join(PERL_DIE_MSGS.union(PERL_WARNINGS)),
        #     *target_files,
        # ])

        stdout = subprocess.check_output([
            "grep",
            "-nF",
            "\n".join(PERL_DIE_MSGS.union(PERL_WARNINGS)),
            *target_files,
        ])

        return (stdout
                .replace(os.path.dirname(self.base_dir).encode() + b"/", b"")
                .strip()
                .decode('utf-8')
                .split('\n'))

    @cached_property
    def final_output(self) -> List[VirmapOutputEntry]:
        results = []

        with open(self.final_fa_filename, "r") as f:
            for line in f:
                line = line.strip()

                tax_match = PAT_TAX_ID.search(line)
                logger.debug(f'tax_match={tax_match}')
                if tax_match:
                    results.append(VirmapOutputEntry(line, tax_match))

                    logger.debug(results[-1])

        return results

    def _copy_log_files(self, dest_dir: str):
        shutil.copytree(
            self.target,
            os.path.join(dest_dir, os.path.basename(self.target)),
            dirs_exist_ok=True,
        )
        shutil.move(
            os.path.join(
                dest_dir, os.path.basename(self.target), f"{self.name}.final.fa"
            ),
            os.path.join(dest_dir, f"{self.name}.final.fa"),
        )

        shutil.copytree(
            self.target_tmp,
            os.path.join(dest_dir, os.path.basename(self.target_tmp)),
            dirs_exist_ok=True,
        )

        file_map_fn = os.path.join(dest_dir, "file_map.dot")
        if os.path.exists(file_map_fn):
            # TODO check dot is available
            subprocess.check_call(["dot", "-Tpdf", "-O", file_map_fn])
