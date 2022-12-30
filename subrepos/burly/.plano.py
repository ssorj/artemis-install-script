#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

from plano import *

@command
def test(verbose=False, coverage=False):
    extract("assert")

    if not WINDOWS:
        check_program("bats")

        if coverage:
            check_program("kcov")

            run(f"kcov ~/coverage bats {'--trace' if verbose else ''} tests/main.sh")
        else:
            run(f"bats {'--trace' if verbose else ''} tests/main.sh")

    run("sh tests/install.sh")

    if not WINDOWS:
        for shell in "ash", "bash", "dash", "ksh", "mksh", "yash", "zsh":
            if which(shell):
                run(f"{shell} tests/install.sh")

@command
def lint():
    """
    Use shellcheck to scan for problems
    """

    check_program("shellcheck")

    run("shellcheck --shell sh --enable all --exclude SC3043,SC2310,SC2312 burly.sh")

@command
def clean():
    remove("build")
    remove("coverage")
    remove(find("__pycache__"))

@command
def extract(*function_names):
    code = read("burly.sh")

    boilerplate = extract_boilerplate(code)
    funcs = extract_functions(code)

    print(boilerplate)

    for name in function_names:
        print(funcs[name])

def extract_boilerplate(code):
    import re

    boilerplate = re.search(r"# BEGIN BOILERPLATE\n(.*?)\n# END BOILERPLATE", code, re.DOTALL)

    if boilerplate:
        return boilerplate.group(1).strip()

def extract_functions(code):
    import re

    functions = dict()
    matches = re.finditer(r"\n(\w+)\s*\(\)\s+{\n.*?\n}", code, re.DOTALL)

    for match in matches:
        functions[match.group(1)] = match.group(0)

    return functions
