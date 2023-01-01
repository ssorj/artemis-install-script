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
def build():
    burly_in = read("burly.sh").strip()

    boilerplate = extract_boilerplate(burly_in)
    functions = extract_functions(burly_in)

    core_function_names = [
        "assert",
        "random_number",
        "print", "print_result", "print_section",
        "run", "log", "fail",
        "green", "yellow", "red", "bold",
        "init_logging", "handle_exit",
        "enable_debug_mode",
        "enable_strict_mode",
    ]

    install_function_names = core_function_names + [
        "port_is_active",
        "await_port_is_active",
        "await_port_is_free",
        "program_is_available",
        "check_java",
        "check_required_ports",
        "check_required_programs",
        "check_required_program_sha512sum",
        "check_required_network_resources",
        "check_writable_directories",
        "save_backup",
        "ask_to_proceed",
        "extract_archive",
        "generate_password",
    ]

    uninstall_function_names = core_function_names + [
        "check_writable_directories",
        "save_backup",
        "ask_to_proceed",
    ]

    burly_out = [boilerplate]

    for name in install_function_names:
        burly_out.append(functions[name])

    install_sh_in = read("install.sh.in")
    install_sh = replace(install_sh_in, "@burly@", "\n".join(burly_out))

    burly_out = [boilerplate]

    for name in uninstall_function_names:
        burly_out.append(functions[name])

    uninstall_sh_in = read("uninstall.sh.in")
    uninstall_sh = replace(uninstall_sh_in, "@burly@", "\n".join(burly_out))

    write("install.sh", install_sh)
    write("uninstall.sh", uninstall_sh)

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

@command
def clean():
    remove(find(".", "__pycache__"))

@command
def test(shell="sh", verbose=False, debug=False):
    check_program(shell)

    build()

    if debug:
        ENV["DEBUG"] = "1"

    try:
        run(f"{shell} {'-o igncr' if WINDOWS else ''} install.sh {'-v' if verbose else ''}".strip())
        run(f"{shell} {'-o igncr' if WINDOWS else ''} uninstall.sh {'-v' if verbose else ''}".strip())
    finally:
        if debug:
            del ENV["DEBUG"]

@command
def test_getting_started(shell="sh", verbose=False, debug=False):
    check_program("curl")
    check_program("pip")

    run("curl https://raw.githubusercontent.com/ssorj/artemis-install-script/main/install.sh | sh", shell=True)
    run("pip install --index-url https://test.pypi.org/simple/ ssorj-qtools")

    with start("artemis run"):
        await_port(5672)

        run("artemis queue create --name greetings --address greetings --auto-create-address --anycast --silent")
        run("qsend amqp://localhost/greetings hello")
        run("qreceive amqp://localhost/greetings --count 1")

@command
def big_test(verbose=False, debug=False):
    test(verbose=True, debug=debug)
    test(verbose=False, debug=debug)

    test(verbose=verbose, debug=True)
    test(verbose=verbose, debug=False)

    for shell in "ash", "bash", "dash", "ksh", "mksh", "yash", "zsh":
        if which(shell):
            test(shell=shell, verbose=verbose, debug=debug)

    with working_env():
        run(f"sh install.sh") # No existing installation and no existing backup
        run(f"sh install.sh") # Creates a backup
        run(f"sh install.sh") # Backs up the backup

        run(f"sh uninstall.sh")

@command
def lint():
    check_program("shellcheck")

    build()

    run("shellcheck --enable all --exclude SC3043 install.sh uninstall.sh")
