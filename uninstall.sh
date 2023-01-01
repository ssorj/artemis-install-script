#!/bin/sh
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

troubleshooting_url="https://github.com/ssorj/artemis-install-script/blob/main/troubleshooting.md"

# Make the local keyword work with ksh93 and POSIX-style functions
case "${KSH_VERSION:-}" in
    *" 93"*) alias local="typeset -x" ;;
    *) ;;
esac

# Make zsh emulate the Bourne shell
if [ -n "${ZSH_VERSION:-}" ]
then
    emulate sh
fi

# This is required to preserve the Windows drive letter in the
# path to HOME
case "$(uname)" in
    CYGWIN*) HOME="$(cygpath --mixed --windows "${HOME}")" ;;
    *) ;;
esac

assert() {
    local location="$0:"

    # shellcheck disable=SC2128 # We want only the first element of the array
    if [ -n "${BASH_LINENO:-}" ]
    then
        location="$0:${BASH_LINENO}:"
    fi

    if ! "$@" > /dev/null 2>&1
    then
        printf "%s %s assert %s\n" "$(red "ASSERTION FAILED:")" "$(yellow "${location}")" "$*" >&2
        exit 1
    fi
}

random_number() {
    printf "%s%s" "$(date +%s)" "$$"
}

print() {
    if [ "$#" = 0 ]
    then
        printf "\n" >&5
        printf -- "--\n"
        return
    fi

    printf "   %s\n" "$1" >&5
    printf -- "-- %s\n" "$1"
}

print_result() {
    printf "   %s\n\n" "$(green "$1")" >&5
    log "Result: $(green "$1")"
}

print_section() {
    printf "== %s ==\n\n" "$(bold "$1")" >&5
    printf "== %s\n" "$1"
}

run() {
    printf -- "-- Running '%s'\n" "$*" >&2
    "$@"
}

log() {
    printf -- "-- %s\n" "$1"
}

fail() {
    printf "   %s %s\n\n" "$(red "ERROR:")" "$1" >&5
    log "$(red "ERROR:") $1"

    if [ -n "${2:-}" ]
    then
        printf "   See %s\n\n" "$2" >&5
        log "See $2"
    fi

    suppress_trouble_report=1

    exit 1
}

green() {
    printf "[0;32m%s[0m" "$1"
}

yellow() {
    printf "[0;33m%s[0m" "$1"
}

red() {
    printf "[1;31m%s[0m" "$1"
}

bold() {
    printf "[1m%s[0m" "$1"
}

init_logging() {
    local log_file="$1"
    local verbose="$2"

    # shellcheck disable=SC2064 # We want to expand these now, not later
    trap "handle_exit '${log_file}' '${verbose}'" EXIT

    if [ -e "${log_file}" ]
    then
        mv "${log_file}" "${log_file}.$(date +%Y-%m-%d).$(random_number)"
    fi

    # Use file descriptor 5 for the default display output
    exec 5>&1

    # Use file descriptor 6 for logging and command output
    exec 6>&2

    # Save stdout and stderr before redirection
    exec 7>&1
    exec 8>&2

    # If verbose, suppress the default display output and log
    # everything to the console. Otherwise, capture logging and
    # command output to the log file.
    if [ -n "${verbose}" ]
    then
        exec 5> /dev/null
    else
        exec 6> "${log_file}"
    fi
}

handle_exit() {
    # This must go first
    local exit_code=$?

    local log_file="$1"
    local verbose="$2"

    # Restore stdout and stderr
    exec 1>&7
    exec 2>&8

    # shellcheck disable=SC2181 # This is intentionally indirect
    if [ "${exit_code}" != 0 ] && [ -z "${suppress_trouble_report:-}" ]
    then
        if [ -n "${verbose}" ]
        then
            printf "%s Something went wrong.\n\n" "$(red "TROUBLE!")"
        else
            printf "   %s Something went wrong.\n\n" "$(red "TROUBLE!")"
            printf "== Log ==\n\n"

            sed -e "s/^/  /" < "${log_file}" || :

            printf "\n"
        fi
    fi
}

enable_debug_mode() {
    # Print the input commands and their expanded form to the console
    set -vx

    if [ -n "${BASH:-}" ]
    then
        # Bash offers more details
        export PS4='[0;33m${BASH_SOURCE}:${LINENO}:[0m ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    fi
}

enable_strict_mode() {
    # No clobber, exit on error, and fail on unbound variables
    set -Ceu

    if [ -n "${BASH:-}" ]
    then
        # Inherit traps, fail fast in pipes, enable POSIX mode, and
        # disable brace expansion
        #
        # shellcheck disable=SC3040,SC3041 # We know this is Bash in this case
        set -E -o pipefail -o posix +o braceexpand

        assert test -n "${POSIXLY_CORRECT}"
    fi
}

check_writable_directories() {
    log "Checking for permission to write to the install directories"

    local dirs="$*"
    local dir=
    local base_dir=
    local unwritable_dirs=

    for dir in ${dirs}
    do
        log "Checking directory '${dir}'"

        base_dir="${dir}"

        while [ ! -e "${base_dir}" ]
        do
            base_dir="$(dirname "${base_dir}")"
        done

        if [ -w "${base_dir}" ]
        then
            printf "Directory '%s' is writable\n" "${base_dir}"
        else
            printf "Directory '%s' is not writeable\n" "${base_dir}"
            unwritable_dirs="${unwritable_dirs}${base_dir}, "
        fi
    done

    if [ -n "${unwritable_dirs}" ]
    then
        fail "Some install directories are not writable: ${unwritable_dirs%??}" \
             "${troubleshooting_url}#some-install-directories-are-not-writable"
    fi
}

save_backup() {
    local backup_dir="$1"
    local config_dir="$2"
    local share_dir="$3"
    local state_dir="$4"

    shift 4

    local bin_files="$*"
    local bin_file=

    log "Saving the previous config dir"

    if [ -e "${config_dir}" ]
    then
        mkdir -p "${backup_dir}/config"
        mv "${config_dir}" "${backup_dir}/config"
    fi

    log "Saving the previous share dir"

    if [ -e "${share_dir}" ]
    then
        mkdir -p "${backup_dir}/share"
        mv "${share_dir}" "${backup_dir}/share"
    fi

    log "Saving the previous state dir"

    if [ -e "${state_dir}" ]
    then
        mkdir -p "${backup_dir}/state"
        mv "${state_dir}" "${backup_dir}/state"
    fi

    for bin_file in ${bin_files}
    do
        if [ -e "${bin_file}" ]
        then
            mkdir -p "${backup_dir}/bin"
            mv "${bin_file}" "${backup_dir}/bin"
        fi
    done

    assert test -d "${backup_dir}"
}

ask_to_proceed() {
    while true
    do
        printf "   Do you want to proceed? (yes or no): " >&5
        printf -- "-- Do you want to proceed? (yes or no): "
        read -r response

        case "${response}" in
            yes) break ;;
            no)  exit  ;;
            *) ;;
        esac
    done
}

usage() {
    local error="${1:-}"

    if [ -n "${error}" ]
    then
        printf "%b %s\n\n" "$(red "ERROR:")" "${*}"
    fi

    cat <<EOF
Usage: ${0} [-hvy] [-s <scheme>]

A script that uninstalls ActiveMQ Artemis

Options:
  -h            Print this help text and exit
  -i            Operate in interactive mode
  -s <scheme>   Select the installation scheme (default "home")
  -v            Print detailed logging to the console

Installation schemes:
  home          Install to ~/.local and ~/.config
  opt           Install to /opt, /var/opt, and /etc/opt
EOF

    if [ -n "${error}" ]
    then
        exit 1
    fi

    exit 0
}

main() {
    enable_strict_mode

    if [ -n "${DEBUG:-}" ]
    then
        enable_debug_mode
    fi

    local scheme="home"
    local verbose=
    local interactive=

    while getopts :his:v option
    do
        case "${option}" in
            h)
                usage
                ;;
            i)
                interactive=1
                ;;
            s)
                scheme="${OPTARG}"
                ;;
            v)
                verbose=1
                ;;
            *)
                usage "Unknown option: ${OPTARG}"
                ;;
        esac
    done

    case "${scheme}" in
        home)
            artemis_bin_dir="${HOME}/.local/bin"
            artemis_config_dir="${HOME}/.config/artemis"
            artemis_home_dir="${HOME}/.local/share/artemis"
            artemis_instance_dir="${HOME}/.local/state/artemis"
            ;;
        opt)
            artemis_bin_dir="/opt/artemis/bin"
            artemis_config_dir="/etc/opt/artemis"
            artemis_home_dir="/opt/artemis"
            artemis_instance_dir="/var/opt/artemis"
            ;;
        *)
            usage "Unknown installation scheme: ${scheme}"
            ;;
    esac

    local work_dir="${HOME}/artemis-install-script"
    local log_file="${work_dir}/uninstall.log"
    local backup_dir="${work_dir}/backup"

    mkdir -p "${work_dir}"
    cd "${work_dir}"

    init_logging "${log_file}" "${verbose}"

    {
        if [ -e "${backup_dir}" ]
        then
            mv "${backup_dir}" "${backup_dir}.$(date +%Y-%m-%d).$(random_number)"
        fi

        if [ -n "${interactive}" ]
        then
            print_section "Preparing to uninstall"

            print "This script will uninstall ActiveMQ Artemis from the following locations:"
            print
            print "    CLI tools:         ${artemis_bin_dir}"
            print "    Config files:      ${artemis_config_dir}"
            print "    Artemis home:      ${artemis_home_dir}"
            print "    Artemis instance:  ${artemis_instance_dir}"
            print
            print "It will save a backup of the existing installation to:"
            print
            print "    ${backup_dir}"
            print
            print "Run \"uninstall.sh -h\" to see the uninstall options."
            print

            ask_to_proceed

            print
        fi

        print_section "Checking prerequisites"

        if [ ! -e "${artemis_config_dir}" ] && [ ! -e "${artemis_home_dir}" ] && [ ! -e "${artemis_instance_dir}" ]
        then
            fail "There is no existing installation to remove"
        fi

        check_writable_directories "${artemis_bin_dir}" \
                                   "$(dirname "${artemis_config_dir}")" \
                                   "$(dirname "${artemis_home_dir}")" \
                                   "$(dirname "${artemis_instance_dir}")"

        print_result "OK"

        print_section "Saving the existing installation to a backup"

        save_backup "${backup_dir}" \
                    "${artemis_config_dir}" "${artemis_home_dir}" "${artemis_instance_dir}" \
                    "${artemis_bin_dir}/artemis" "${artemis_bin_dir}/artemis-service"

        print_result "OK"

        print_section "Removing the existing installation"

        if [ -e "${artemis_bin_dir}/artemis" ]
        then
            rm "${artemis_bin_dir}/artemis"
        fi

        if [ -e "${artemis_bin_dir}/artemis-service" ]
        then
            rm "${artemis_bin_dir}/artemis-service"
        fi

        if [ -e "${artemis_config_dir}" ]
        then
            rm -rf "${artemis_config_dir}"
        fi

        if [ -e "${artemis_home_dir}" ]
        then
            rm -rf "${artemis_home_dir}"
        fi

        if [ -e "${artemis_instance_dir}" ]
        then
            rm -rf "${artemis_instance_dir}"
        fi

        print_result "OK"

        print_section "Summary"

        print_result "SUCCESS"

        print "ActiveMQ Artemis has been uninstalled."
        print
        print "    Backup:  ${backup_dir}"
        print
        print "To install Artemis again, use:"
        print
        print "    curl -f https://raw.githubusercontent.com/ssorj/persephone/main/artemis/install.sh | sh"
        print
    } >&6 2>&6
}

main "$@"
