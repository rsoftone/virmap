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
