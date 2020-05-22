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

from collections import Counter
from typing import Iterable

import xlsxwriter

from constants import *
from sample_results import SampleResults
from util import get_logger

logger = get_logger(__name__)


class AggregStatsWorkbook:
    def __init__(self, out_fn: str):
        self.all_walltimes = {}
        self.all_cputimes = {}
        self.all_cpuratios = {}
        self.all_tax_data = {}
        self.all_summary = {}

        self.workbook = xlsxwriter.Workbook(out_fn)

        self.color_scale = {
            "type": "3_color_scale",
            "min_type": "value",
            "mid_type": "percentile",
            "max_type": "max",
            "min_value": "0.001388889",
            "mid_value": "50",
            # "max_value": "XXXX",
            "min_color": "#ff0000",
            "mid_color": "#ffff00",
            "max_color": "#00CC00",
        }
        self.inverse_color_scale = {
            "type": "3_color_scale",
            "min_type": "value",
            "mid_type": "percentile",
            "max_type": "max",
            "min_value": "0.001388889",
            "mid_value": "50",
            # "max_value": "XXXX",
            "min_color": "#00CC00",
            "mid_color": "#ffff00",
            "max_color": "#ff0000",
        }
        self.header_fmt = self.workbook.add_format({"bold": True, "rotation": 15})
        self.header_height = 50
        self.time_fmt_hrs = self.workbook.add_format({"num_format": "[hh]:mm:ss"})
        self.time_fmt = self.workbook.add_format({"num_format": "mm:ss"})

    def write_sample_dict(
            self, ws, row: int, col: int, data, headers, no_time: bool = False
    ) -> int:
        ws.set_column(0, 0, 25)
        # ws.set_column(col+1, col+len(headers), 9)
        ws.set_row(row, self.header_height)
        for idx, header in enumerate(headers):
            ws.write(row, col + idx, header, self.header_fmt)

            ws.conditional_format(
                row + 1,
                col + idx,
                row + len(data),
                col + idx,
                self.inverse_color_scale if not no_time else self.color_scale,
            )

        for row_idx, sample in enumerate(sorted(data.keys())):
            ws.write(row + 1 + row_idx, col, sample)

            for col_idx, cell_data in enumerate(data[sample]):
                if not no_time:
                    if cell_data is None:
                        ws.write(
                            row + 1 + row_idx,
                            col + 1 + col_idx,
                            '-',
                        )
                    else:
                        cell_fmt = self.time_fmt_hrs if cell_data >= 3600 else self.time_fmt
                        ws.write(
                            row + 1 + row_idx,
                            col + 1 + col_idx,
                            cell_data / 86400,
                            cell_fmt,
                        )
                else:
                    ws.write(row + 1 + row_idx, col + 1 + col_idx, cell_data)

        return row_idx + row + 1

    def dump_summary(self):
        green_format = self.workbook.add_format({"bg_color": "#33CC33"})
        red_format = self.workbook.add_format({"bg_color": "#CC3333"})
        orange_format = self.workbook.add_format({"bg_color": "#ff860d"})

        ws_summary = self.workbook.add_worksheet("Summary")
        ws_summary.set_row(0, self.header_height)
        ws_summary.write_row(
            0,
            0,
            [
                "Sample",
                "Benign errors",
                "Unexpected errors",
                "Killed count",
                "Output seqs",
                "Unique taxids",
                "Generic virus outputs",
                *sorted(VIRMAP_TAX_FLAGS)
            ],
            self.header_fmt,
        )
        ws_summary.set_column(0, 0, 25)
        ws_summary.set_column(1, 6, 7)

        # benign errors
        ws_summary.conditional_format(
            1,
            1,
            len(self.all_summary),
            1,
            {"type": "cell", "criteria": "==", "value": 15, "format": green_format, },
        )
        ws_summary.conditional_format(
            1,
            1,
            len(self.all_summary),
            1,
            {"type": "cell", "criteria": "!=", "value": 15, "format": red_format, },
        )

        # critical errors
        ws_summary.conditional_format(
            1,
            2,
            len(self.all_summary),
            3,
            {"type": "cell", "criteria": "==", "value": 0, "format": green_format, },
        )
        ws_summary.conditional_format(
            1,
            2,
            len(self.all_summary),
            3,
            {"type": "cell", "criteria": "!=", "value": 0, "format": red_format, },
        )

        ws_summary.conditional_format(
            1,
            6,
            len(self.all_summary),
            6,
            {
                "type": "cell",
                "criteria": "between",
                "minimum": 1,
                "maximum": 2,
                "format": orange_format,
            },
        )
        ws_summary.conditional_format(
            1,
            6,
            len(self.all_summary),
            6,
            {"type": "cell", "criteria": ">=", "value": 3, "format": red_format, },
        )
        # ws_summary.conditional_format(
        #     1,
        #     6,
        #     len(self.all_summary),
        #     6,
        #     {"type": "cell", "criteria": "==", "value": 0, "format": green_format,},
        # )

        for idx, sample in enumerate(sorted(self.all_summary)):
            summary = self.all_summary[sample]
            flag_counts = summary[-1]

            # ws_summary.set_column(3, 8, 20)
            ws_summary.write(idx + 1, 0, sample)
            ws_summary.write_row(idx + 1, 1, summary[:-1])
            for flag_idx, flag in enumerate(sorted(VIRMAP_TAX_FLAGS)):
                ws_summary.write(idx + 1, 1 + len(summary) - 1 + flag_idx, flag_counts[flag])

            # output seqs vs uniq
            ws_summary.conditional_format(
                idx + 1,
                4,
                idx + 1,
                4,
                {
                    "type": "cell",
                    "criteria": ">=",
                    "value": f"F{idx + 2} * 1.5",
                    "format": orange_format,
                },
            )

    def dump_time_stats(self):
        ws_walltimes = self.workbook.add_worksheet("Walltimes")
        row = self.write_sample_dict(
            ws_walltimes, 0, 0, self.all_walltimes, ("Sample",) + TIME_CATEGORIES
        )

        ws_cpuratio = self.workbook.add_worksheet("CPU ratio")
        row = self.write_sample_dict(
            ws_cpuratio,
            0,
            0,
            self.all_cpuratios,
            ("Sample",) + TIME_CATEGORIES,
            no_time=True,
        )

        ws_cputime = self.workbook.add_worksheet("CPU time")
        row = self.write_sample_dict(
            ws_cputime, 0, 0, self.all_cputimes, ("Sample",) + TIME_CATEGORIES
        )

    def dump_tax_stats(self):
        all_seq_flags = sorted(list(VIRMAP_TAX_FLAGS))
        num_seq_flags = len(all_seq_flags)
        tax_column_headers = ["tax id", "size", *all_seq_flags, "taxonomy"]

        for sample in sorted(self.all_tax_data):
            tax_data = self.all_tax_data[sample]

            ws = self.workbook.add_worksheet(sample[:31])
            ws.write_row(0, 0, tax_column_headers)
            ws.set_column(0, 8, 8)
            ws.set_column(9, 12, 20)
            for idx, tax_entry in enumerate(tax_data):
                tax_id, size, seq_flags = tax_entry[0:3]
                taxonomy = tax_entry[3]

                ws.write(idx + 1, 0, int(tax_id))
                ws.write(idx + 1, 1, int(size))
                for flag_idx, flag in enumerate(all_seq_flags):
                    if flag in seq_flags:
                        ws.write(idx + 1, 2 + flag_idx, 1)

                ws.write_row(idx + 1, 2 + num_seq_flags, taxonomy)
            # row = self.write_sample_dict(
            #     ws, 0, 0, self.all_walltimes, ("Sample",) + TIME_CATEGORIES
            # )

            ws.autofilter(0, 0, len(tax_data), len(tax_column_headers) + 4)

    def process(self, samples: Iterable[SampleResults]):
        logger.info("Building workbook")

        for sample in samples:
            logger.debug(sample)

            walltimes, cputimes, cpuratios = sample.simple_timing_info
            self.all_walltimes[sample.run_name] = walltimes
            self.all_cputimes[sample.run_name] = cputimes
            self.all_cpuratios[sample.run_name] = cpuratios
            tax_data = self.all_tax_data[sample.run_name] = []
            flag_counts = Counter()
            summary = self.all_summary[sample.run_name] = [0, 0, 0, 0, 0, 0, flag_counts]

            # ["Benign errors", "Critcal errors", "Killed count", "Output sequences", "Unique output taxids"],

            for line in sample.warnings_and_errors:
                line = line.strip()

                if any(map(lambda x: x.search(line), BENIGN_ERRORS)):
                    summary[0] += 1  # benign
                else:
                    summary[1] += 1  # critical
                    # logger.warning(f'Critical error in {sample.run_name!r}: {line!r}')

                if "Killed" in line:
                    summary[2] += 1  # killed

            # Extract results
            for entry in sample.final_output:
                tax_data.append([entry.tax_id, entry.tax_size, entry.flags, entry.taxonomy])

            summary[3] = len(tax_data)
            summary[4] = len(set(map(lambda x: x[0], tax_data)))
            summary[5] = len(list(filter(lambda x: x[0] == 10239, tax_data)))

        logger.info("Adding summary")
        self.dump_summary()

        logger.info("Adding time stats")
        self.dump_time_stats()

        logger.info("Adding taxonomy stats")
        self.dump_tax_stats()

        logger.info("Saving workbook")
        self.close()

    def close(self):
        self.workbook.close()
