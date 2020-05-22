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

import json
import os
import re

from analyse_times.node import Node

PAT_BBMAP = re.compile(r"^(.*?):\s+([\d.]+) seconds", re.IGNORECASE | re.MULTILINE)
PAT_DIAMOND = re.compile(
    r"^(.*?)...\s+\[([\d.]+)s\]$|^(Total time) = ([\d.]+)s$",
    re.IGNORECASE | re.MULTILINE,
)
PAT_ITER_CYCLES = re.compile(
    r"(^Cycle (\d+) started(?:.*\n)*(\d+) seconds for cycle \2)$",
    re.IGNORECASE | re.MULTILINE,
)
PAT_ITER_IMP_TOTAL = re.compile(r"Overall improve time: (\d+) seconds", re.IGNORECASE)
PAT_TIME_SECONDS = re.compile(r"(.*?):?[\t ]*([\d.]+) seconds", re.IGNORECASE)
PAT_PBS_WALLTIME = re.compile(r"Walltime Used: (\d+:\d+:\d+)")


def build_timing_tree(sample):
    from sample_results import SampleResults
    assert isinstance(sample, SampleResults)

    pat_time = re.compile(
        "TIME "
        + sample.name
        + r" (.*?): ([\d.]+) seconds, ([\d.]+) CPU seconds, ([\d.]+) CPU ratio",
        re.IGNORECASE,
    )

    tree = Node("root")
    with open(f"{sample.prefix}.log", "r") as f:
        for match in pat_time.finditer(f.read()):
            n = Node(match.group(1), match.group(2), match.group(3), match.group(4))
            if n.name.startswith("Overall"):
                tree.replace_with(n)
            else:
                if n.name == "bbmap to virus":
                    bb_root = n.append(Node("bb_root"))
                    with open(sample.prefix + ".bbmap.err", "r") as bb_f:
                        for bb_match in PAT_BBMAP.finditer(bb_f.read()):
                            bb_node = Node(bb_match.group(1), bb_match.group(2))
                            if bb_node.name == "Total time":
                                bb_root.replace_with(bb_node)
                            else:
                                bb_root.append(bb_node)
                elif n.name == "diamond to virus":
                    bss_root = n.append(Node("bss_root"))

                    with open(
                            sample.tmp_prefix + ".buildSuperScaffolds.err", "r"
                    ) as bss_f:
                        for bss_match in PAT_DIAMOND.finditer(bss_f.read()):
                            if bss_match.group(3):
                                bss_root.replace_with(
                                    Node(bss_match.group(3), bss_match.group(4))
                                )
                            else:
                                bss_root.append(
                                    Node(bss_match.group(1), bss_match.group(2))
                                )
                elif n.name == "diamond filter map":
                    dfm_root = n.append(Node("dfm_root"))

                    with open(sample.tmp_prefix + ".filter.err", "r") as dfm_f:
                        for dfm_match in PAT_DIAMOND.finditer(dfm_f.read()):
                            if dfm_match.group(3):
                                dfm_root.replace_with(
                                    Node(dfm_match.group(3), dfm_match.group(4))
                                )
                            else:
                                dfm_root.append(
                                    Node(dfm_match.group(1), dfm_match.group(2))
                                )
                elif n.name == "iterative improvement":
                    ii_root = n

                    with open(sample.tmp_prefix + ".iterateImprove.err", "r") as ii_f:
                        ii_data = ii_f.read()
                        # ii_root.time = PAT_ITER_IMP_TOTAL.search(ii_data).group(1)

                        for ii_cycle in PAT_ITER_CYCLES.finditer(ii_data):
                            ii_cyc_num, ii_cyc_time, ii_cyc = (
                                ii_cycle.group(2),
                                ii_cycle.group(3),
                                ii_cycle.group(1),
                            )

                            ii_node = ii_root.append(
                                Node(f"Cycle {ii_cyc_num}", ii_cyc_time)
                            )

                            for ii_match in PAT_TIME_SECONDS.finditer(ii_cyc):
                                iit_name, iit_time = (
                                    ii_match.group(1),
                                    ii_match.group(2),
                                )
                                if iit_name not in {
                                    "finished reading SAM after",
                                    "Total time",
                                    "THREADING took",
                                    "Overall pileup time",
                                }:
                                    continue

                                ii_node.append(Node(iit_name, iit_time))
                elif n.name == "diamond full":
                    df_root = n

                    with open(sample.prefix + ".diamondBlastx.err", "r") as df_f:
                        for df_match in PAT_DIAMOND.finditer(df_f.read()):
                            df_root.append(
                                Node(df_match.group(1), df_match.group(2))
                            )

                tree.append(n)

    if tree.time is None and sample.pbs_log_fn:
        # try to find used walltime appended by pbs
        with open(sample.pbs_log_fn, "r") as f:
            match = PAT_PBS_WALLTIME.search(f.read())
            if match is not None:
                tree.name = "root - DID NOT COMPLETE"
                tree.time = sum(
                    int(x) * 60 ** exponent
                    for exponent, x in enumerate(match.group(1).split(":")[::-1])
                )

    return tree


def dump_timing_tree(dest_dir: str, sample):
    from sample_results import SampleResults
    assert isinstance(sample, SampleResults)

    json_tree = json.dumps(sample.detailed_timing_info.to_json(), indent=2)

    with open(os.path.join(os.path.dirname(__file__), "flame_template.html"), "r") as f:
        html_template = f.read()

    template_title = re.compile(
        r"{\s*TEMPLATE_TITLE\s*}", re.IGNORECASE | re.MULTILINE
    )
    template_data = re.compile(
        r"{\s*TEMPLATE_DATA\s*}", re.IGNORECASE | re.MULTILINE
    )
    template_js_title = re.compile(
        r"{\s*TEMPLATE_JS_TITLE\s*}", re.IGNORECASE | re.MULTILINE
    )

    with open(os.path.join(dest_dir, f"flame.html"), "w") as f:
        html_template = template_title.sub(sample.run_name, html_template)
        html_template = template_js_title.sub(
            json.dumps(sample.run_name), html_template
        )
        html_template = template_data.sub(json_tree, html_template)
        f.write(html_template)


# TODO relies on a modified version of VirMap
def graph_cmd_io(self, pbs_log_fn):
    output_patterns = [
        re.compile(r"(?<![2>])>>?\s*([^\s]+)"),  # stdout redirect
        re.compile(r"[\s-](?:-o\s|out(?:put)?m?[=\s])\s*([^\s]+)"),  # as param
        re.compile(r"cp [^\s+]+\s*([^\s]+)"),  # copy destination
    ]

    with open(os.path.join(self.out_dir, "file_map.dot"), "w") as dot_f:
        files = set()
        file_counter = 0
        file_counter_map = {}

        def get_file_node(fn):
            nonlocal file_counter

            # fn = fn.split(self.run_name, 1)[1]
            if self.run_name in fn:
                fn = (
                    fn[fn.index(self.run_name):]
                        .replace(f"{self.run_name}/{self.name}.", "out/")
                        .replace(f"{self.run_name}_tmp/{self.name}.", "tmp/")
                )

            if fn not in file_counter_map:
                file_counter += 1
                file_counter_map[fn] = f"file_{file_counter}"

            return file_counter_map[fn]

        with open(pbs_log_fn, "r") as f:
            dot_f.write("digraph G{\n")
            last_node = None

            for idx, line in enumerate(f):
                line = line.strip()

                if not line.startswith("Executing: "):
                    continue

                tokens = line.split(" ")[1:]
                if tokens[0] in {"mkdir", "echo"}:
                    continue
                file_set = set(
                    filter(
                        lambda x: f"/{self.run_name}" in x
                                  and f"/{self.name}." in x
                                  and not x.startswith("2")
                                  and not x.startswith("1"),
                        map(lambda x: x.split("=")[-1], tokens),
                    )
                )

                output_set = set(
                    map(
                        lambda x: x.group(1),
                        filter(
                            bool, map(lambda x: x.search(line), output_patterns)
                        ),
                    )
                )
                if not output_set:
                    continue

                files.update(file_set)
                file_set -= output_set

                line_node = f"exec_{idx + 1}"
                dot_f.write(
                    f"\t{line_node} [label={json.dumps(tokens[0])}, shape=rect];\n"
                )
                if last_node is not None:
                    dot_f.write(
                        f"\t{last_node} -> {line_node} [weight=5, penwidth=4];\n"
                    )
                last_node = line_node
                for fn in file_set:
                    dot_f.write(f"\t{get_file_node(fn)} -> {line_node};\n")
                for output in output_set:
                    dot_f.write(
                        f"\t{line_node} -> {get_file_node(output)} [color=green];\n"
                    )

            for fn, file_node in file_counter_map.items():
                dot_f.write(f"\t{file_node} [label={json.dumps(fn)}];\n")

            dot_f.write("}\n")
