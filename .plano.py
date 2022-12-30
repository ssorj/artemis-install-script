from plano import *

@command
def build():
    burly_in = read("burly.sh").strip()

    boilerplate = extract_boilerplate(burly_in)
    functions = extract_functions(burly_in)

    function_names = [
        "assert",
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
        "init_logging", "handle_exit",
        "enable_debug_mode",
        "enable_strict_mode",
        "run", "log", "fail",
        "print", "print_result", "print_section",
        "green", "yellow", "red", "bold",
        "save_backup",
        "ask_to_proceed",
        "extract_archive",
        "generate_password",
        "random_number",
    ]

    burly_out = [boilerplate]

    for name in function_names:
        burly_out.append(functions[name])

    install_sh_in = read("install.sh.in")
    install_sh = replace(install_sh_in, "@burly@", "\n".join(burly_out))

    # uninstall_sh_in = read("uninstall.sh.in")
    # uninstall_sh = replace(uninstall_sh_in, "@burly@", burly)

    write("install.sh", install_sh)
    # write("uninstall.sh", uninstall_sh)

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
