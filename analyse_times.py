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

import json
import os
import pickle
import re
import shutil
from collections import defaultdict
from itertools import chain
from subprocess import check_call, check_output

PERL_DIE_MSGS = {
    "Could not open file",
    "no acc on",
    "no acc on after",
    "can't open DB",
    "what?",
    "Could not close file",
    "pad is not a number",
    "casemask is empty",
    "Could not close file",
    "has no parent, line =",
    "no position information in",
    "can't strip end info off  no ;codonStart=",
    "has no coordinates",
    "can't grab position information on",
    "no valid position information",
    "can't get taxId on reference",
    "pad is not a number",
    "double double reverse reverse bug",
    "isn't in sizes",
    "sem failed:",
}
PERL_WARNINGS = {
    "Perl exited with active threads",
    "Use of uninitialized value",
    "Exception in thread",
    "isn't numeric in numeric",
    "FAlite: Empty",
    "BLAST Database error",
    "Error open",
    "exceeded memory allocation",
    "Killed",
    "Broken pipe",
    "read failed",
    "write failed",
    "Error detecting",
    "cannot",
}

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
PAT_PBS_LOGFILE = re.compile(r"^.*\.o\d+$")
PAT_VIRMAP_ARGS_OUTPUT = re.compile(r"Virmap called with: .*--outputDir ([^\s]+)")
PAT_PBS_WALLTIME = re.compile(r"Walltime Used: (\d+:\d+:\d+)")
RAW_RESULTS_DIR = "../neto/raw_results"
OUT_RESULTS_DIR = "../neto/results"


def find_name(folder):
    for fn in os.listdir(folder):
        if fn.endswith(".log"):
            return fn[:-4]

    return None


class Node:
    def __init__(
            self,
            name: str,
            time: str = None,
            cpu_seconds: str = None,
            cpu_ratio: str = None,
    ):
        self.name = name
        self.time = time
        self.cpu_seconds = cpu_seconds
        self.cpu_ratio = cpu_ratio
        self.children = []

    def append(self, node):
        self.children.append(node)

        return node

    def to_json(self):
        obj = {"name": self.name, "value": self.time}
        if self.cpu_ratio:
            obj["name"] = f"{self.name}, {self.cpu_ratio} CPU ratio"
        if self.children:
            obj["children"] = list(x.to_json() for x in self.children)

        return obj

    def replace_with(self, other, include_children: bool = False):
        self.name = other.name
        self.time = other.time
        self.cpu_seconds = other.cpu_seconds
        self.cpu_ratio = other.cpu_ratio
        if include_children:
            self.children = other.children


class Run:
    def __init__(self, folder):
        self.run_name = folder
        self.target = f"{RAW_RESULTS_DIR}/{self.run_name}"
        self.target_tmp = f"{RAW_RESULTS_DIR}/{self.run_name}_tmp"
        self.out_dir = f"{OUT_RESULTS_DIR}/{self.run_name}"

        self.name = find_name(self.target)
        self.prefix = os.path.join(self.target, self.name)
        self.tmp_prefix = os.path.join(self.target_tmp, self.name)

        self.pat_time = re.compile(
            "TIME "
            + self.name
            + r" (.*?): ([\d.]+) seconds, ([\d.]+) CPU seconds, ([\d.]+) CPU ratio",
            re.IGNORECASE,
        )

    def dump_tree(self):
        tree = Node("root")
        with open(f"{self.prefix}.log", "r") as f:
            for match in self.pat_time.finditer(f.read()):
                n = Node(match.group(1), match.group(2), match.group(3), match.group(4))
                if n.name.startswith("Overall"):
                    tree.replace_with(n)
                else:
                    if n.name == "bbmap to virus":
                        bb_root = n.append(Node("bb_root"))
                        with open(self.prefix + ".bbmap.err", "r") as bb_f:
                            for bb_match in PAT_BBMAP.finditer(bb_f.read()):
                                bb_node = Node(bb_match.group(1), bb_match.group(2))
                                if bb_node.name == "Total time":
                                    bb_root.replace_with(bb_node)
                                else:
                                    bb_root.append(bb_node)
                    elif n.name == "diamond to virus":
                        bss_root = n.append(Node("bss_root"))

                        with open(
                                self.tmp_prefix + ".buildSuperScaffolds.err", "r"
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

                        with open(self.tmp_prefix + ".filter.err", "r") as dfm_f:
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

                        with open(self.tmp_prefix + ".iterateImprove.err", "r") as ii_f:
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

                        with open(self.prefix + ".diamondBlastx.err", "r") as df_f:
                            for df_match in PAT_DIAMOND.finditer(df_f.read()):
                                df_root.append(
                                    Node(df_match.group(1), df_match.group(2))
                                )

                    tree.append(n)

        if tree.time is None and self.pbs_log_fn:
            # try to find used walltime appended by pbs
            with open(self.pbs_log_fn, "r") as f:
                match = PAT_PBS_WALLTIME.search(f.read())
                if match is not None:
                    tree.name = "root - DID NOT COMPLETE"
                    tree.time = sum(
                        int(x) * 60 ** pow
                        for pow, x in enumerate(match.group(1).split(":")[::-1])
                    )

        json_tree = json.dumps(tree.to_json(), indent=2)

        with open("../neto/flame.html", "r") as f:
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

        with open(os.path.join(self.out_dir, f"flame.html"), "w") as f:
            html_template = template_title.sub(self.run_name, html_template)
            html_template = template_js_title.sub(
                json.dumps(self.run_name), html_template
            )
            html_template = template_data.sub(json_tree, html_template)
            f.write(html_template)

    def find_warn_err(self):
        target_files = [self.pbs_log_fn] if self.pbs_log_fn else []
        for dirpath, dirnames, filenames in chain(
                os.walk(self.target), os.walk(self.target_tmp)
        ):
            for fn in filenames:
                fn = os.path.join(dirpath, fn)

                if fn.rsplit(".", 1)[-1] in {"err", "txt", "log"}:
                    target_files.append(fn)

        check_call(
            [
                "grep",
                "--color",
                "-nF",
                "\n".join(PERL_DIE_MSGS.union(PERL_WARNINGS)),
                *target_files,
            ]
        )

        stdout = check_output(
            [
                "grep",
                "-nF",
                "\n".join(PERL_DIE_MSGS.union(PERL_WARNINGS)),
                *target_files,
            ]
        )

        with open(os.path.join(self.out_dir, f"errors.txt"), "wb") as f:
            f.write(stdout.replace(RAW_RESULTS_DIR.encode() + b"/", b""))

    def find_pbs_log(self):
        for fn in os.listdir(RAW_RESULTS_DIR):
            fn = os.path.join(RAW_RESULTS_DIR, fn)
            if not os.path.isfile(fn) or not PAT_PBS_LOGFILE.match(fn):
                continue

            with open(fn, "r") as f:
                log_data = f.read()

            log_output = PAT_VIRMAP_ARGS_OUTPUT.search(log_data)
            if not log_output:
                continue

            if os.path.basename(log_output.group(1)) == self.run_name:
                shutil.copy(fn, self.out_dir)

                return fn

    def analyse_pbs_log(self, pbs_log_fn):
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

    def final_tax_counts(self, fn):
        PAT_TAX_ID = re.compile(r"\btaxId=(\d+);(?:.*?;)?size=(\d+)", re.IGNORECASE)

        results = []

        with open(fn, "r") as f:
            for l in f:
                m = PAT_TAX_ID.search(l)
                if not m:
                    continue

                tax_id = int(m.group(1))
                size = int(m.group(2))

                results.append(
                    (size, f"taxid={tax_id}, size={size} | {resolve_taxid(tax_id)}\n")
                )

        with open(os.path.join(self.out_dir, "output_taxid_counts.txt"), "w") as f:
            for size, result in sorted(results, key=lambda x: x[0], reverse=True):
                f.write(result)

    def process(self):
        os.makedirs(self.out_dir, exist_ok=True)

        self.pbs_log_fn = self.find_pbs_log()
        if self.pbs_log_fn:
            self.analyse_pbs_log(self.pbs_log_fn)

        self.dump_tree()

        self.find_warn_err()

        shutil.copytree(
            self.target,
            os.path.join(self.out_dir, os.path.basename(self.target)),
            dirs_exist_ok=True,
        )
        shutil.move(
            os.path.join(
                self.out_dir, os.path.basename(self.target), f"{self.name}.final.fa"
            ),
            os.path.join(self.out_dir, f"{self.name}.final.fa"),
        )
        self.final_tax_counts(os.path.join(self.out_dir, f"{self.name}.final.fa"))

        shutil.copytree(
            self.target_tmp,
            os.path.join(self.out_dir, os.path.basename(self.target_tmp)),
            dirs_exist_ok=True,
        )

        check_call(["dot", "-Tpdf", "-O", os.path.join(self.out_dir, "file_map.dot")])


parents = None
ranks = None
names = None


def load_tax_tree():
    global parents, names, ranks
    if parents is not None:
        return parents

    if os.path.exists("../neto/tax_tree.cache"):
        with open("../neto/tax_tree.cache", "rb") as f:
            data = pickle.load(f)

            parents = data["parents"]
            ranks = data["ranks"]
            names = data["names"]

        return

    path = "../taxdump/taxdump"

    sep = re.compile(r"\t\|[\t\n]")

    merged = defaultdict(list)
    with open(f"{path}/merged.dmp", "r") as f:
        for l in f:
            if l.endswith("\t|\n"):
                l = l[:-3]

            old_id, new_id = sep.split(l)

            old_id = int(old_id)
            new_id = int(new_id)

            merged[new_id].append(old_id)

    parents = {}
    ranks = {}
    names = {}

    with open(f"{path}/nodes.dmp", "r") as f:
        for l in f:
            if l.endswith("\t|\n"):
                l = l[:-3]

            (
                taxonomy_id,
                parent_taxonomy_id,
                taxonomy_rank,
                embl_code,
                division_id,
                is_inheriteddivision,
                genetic_code_id,
                is_inherited_genetic_code,
                mitochondrial_genetic_code_id,
                is_inherited_mitochondrial_genetic_code,
                is_hidden_in_genbank,
                is_subtree_hidden,
                comments,
            ) = sep.split(l)

            taxonomy_id = int(taxonomy_id)
            parent_taxonomy_id = int(parent_taxonomy_id)

            parents[taxonomy_id] = parent_taxonomy_id
            ranks[taxonomy_id] = taxonomy_rank

            if taxonomy_id in merged:
                for old_id in merged[taxonomy_id]:
                    parents[old_id] = parent_taxonomy_id
                    ranks[old_id] = taxonomy_rank

    with open(f"{path}/names.dmp", "r") as f:
        for l in f:
            if l.endswith("\t|\n"):
                l = l[:-3]

            (taxonomy_id, name_txt, unique_name, name_class,) = sep.split(l)

            if name_class != "scientific name":
                continue

            taxonomy_id = int(taxonomy_id)
            names[taxonomy_id] = name_txt

            if taxonomy_id in merged:
                for old_id in merged[taxonomy_id]:
                    names[old_id] = name_txt

    with open("../neto/tax_tree.cache", "wb") as f:
        data = {
            "parents": parents,
            "ranks": ranks,
            "names": names,
        }
        pickle.dump(data, f)


def resolve_taxid(taxid):
    load_tax_tree()

    tax_names = []

    while taxid != 1:
        tax_names.append(names[taxid])
        taxid = parents[taxid]

    return " > ".join(reversed(tax_names))


if __name__ == "__main__":
    pass
