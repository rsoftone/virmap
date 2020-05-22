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

import logging

log_formatter = logging.Formatter('%(asctime)s [%(levelname)-5.5s] %(name)s - %(message)s')
root_logger = logging.getLogger()

console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)
console_handler.setLevel(logging.INFO)

root_logger.setLevel(logging.DEBUG)
root_logger.addHandler(console_handler)


def get_logger(name: str) -> logging.Logger:
    return root_logger.getChild(name)
