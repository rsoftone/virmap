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

import re
from collections import defaultdict
import time
from util import get_logger

PAT_SEP = re.compile(r"\t\|[\t\n]")

logger = get_logger(__name__)

parents = None
ranks = None
names = None


def load_tax_tree(path: str):
    global parents, names, ranks
    if parents is not None:
        return

    logger.info("Loading tax tree")
    start_time = time.time()

    merged = defaultdict(list)
    with open(f"{path}/merged.dmp", "r") as f:
        for line in f:
            if line.endswith("\t|\n"):
                line = line[:-3]

            old_id, new_id = PAT_SEP.split(line)

            old_id = int(old_id)
            new_id = int(new_id)

            merged[new_id].append(old_id)

    parents = {}
    ranks = {}
    names = {}

    with open(f"{path}/nodes.dmp", "r") as f:
        for line in f:
            if line.endswith("\t|\n"):
                line = line[:-3]

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
            ) = PAT_SEP.split(line)

            taxonomy_id = int(taxonomy_id)
            parent_taxonomy_id = int(parent_taxonomy_id)

            parents[taxonomy_id] = parent_taxonomy_id
            ranks[taxonomy_id] = taxonomy_rank

            if taxonomy_id in merged:
                for old_id in merged[taxonomy_id]:
                    parents[old_id] = parent_taxonomy_id
                    ranks[old_id] = taxonomy_rank

    with open(f"{path}/names.dmp", "r") as f:
        for line in f:
            if line.endswith("\t|\n"):
                line = line[:-3]

            (taxonomy_id, name_txt, unique_name, name_class,) = PAT_SEP.split(line)

            if name_class != "scientific name":
                continue

            taxonomy_id = int(taxonomy_id)
            names[taxonomy_id] = name_txt

            if taxonomy_id in merged:
                for old_id in merged[taxonomy_id]:
                    names[old_id] = name_txt

    logger.info(f"Finished loading tax tree in {time.time() - start_time:.2f}s")


def resolve_taxid(taxid):
    if parents is None:
        raise ValueError('Tax tree not loaded!')

    tax_names = []

    while taxid != 1:
        tax_names.append(names[taxid])
        taxid = parents[taxid]

    return " > ".join(reversed(tax_names))
