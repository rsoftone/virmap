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

import re
import string

# Pattern matching timing info VirMap outputs
PAT_TIME = re.compile(
    r"TIME .*? (.*?): ([\d.]+) seconds, ([\d.]+) CPU seconds, ([\d.]+) CPU ratio",
    re.IGNORECASE,
)
PAT_RESULTS = re.compile(
    r"taxid=(\d+), size=(\d+) \| ([^>\n]*)(?: > ([^>\n]*)(?: > ([^>\n]*)(?: > ([^>\n]*)(?: > ([^>\n]*)(?: > ([^>\n]*)(?: > ([^>\n]*))?)?)?)?)?)?$",
    re.MULTILINE,
)
BENIGN_ERRORS = (
    re.compile(r"Use of uninitialized value \$nextLine in split .*? line 1857,"),
    re.compile(
        r"Use of uninitialized value \$currentHead in substitution .*? line 1859,"
    ),
    re.compile(r"Use of uninitialized value \$currentHead in string .*? line 1865,"),
    re.compile(r"Use of uninitialized value \$currentHead in string .*? line 1866,"),
    re.compile(r"Use of uninitialized value \$currentHead in string .*? line 1873,"),
    re.compile(r"Use of uninitialized value \$currentHead in hash .*? line 1876,"),
    re.compile(r"Use of uninitialized value \$head in string .*? line 1900,"),
    re.compile(
        r"Use of uninitialized value \$sem in concatenation \(\.\) or string at .*? line 395."
    ),
    # re.compile(r"Use of uninitialized value in numeric comparison \(<=>\) .*? line 1678."),
)
COLNAMES = string.ascii_uppercase
TIME_CATEGORIES = (
    "decompress",
    "dereplicate",
    "normalize",
    "bbmap to virus",
    "diamond to virus",
    "construct superscaffolds",
    "megahit assembly",
    "tadpole assembly",
    "dedupe assembly",
    "merge assembly",
    "diamond filter map",
    "blastn filter map",
    "filter contigs",
    "iterative improvement",
    "self align and quantify",
    "blastn full",
    "diamond full",
    "determine taxonomy",
    "Overall Virmap time",
)
VIRMAP_TAX_FLAGS = {
    "weak",
    "highDivergence",
    "HighOthers",
    "highUnknownInformation",
    "potentialMisannotations",
    "merged",
}
PAT_TAG = re.compile(r"\b(\w+)=1\b")
PAT_TAX_ID = re.compile(r"\btaxId=(\d+);(?:.*?;)?size=(\d+)", re.IGNORECASE)

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
