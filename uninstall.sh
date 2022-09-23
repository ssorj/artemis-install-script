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

# Users of this script can override the troubleshooting URL
if [ -z "${troubleshooting_url:-}" ]
then
    troubleshooting_url="https://github.com/ssorj/burly/blob/main/troubleshooting.md"
fi

# Make the local keyword work with ksh93 and POSIX-style functions
case "${KSH_VERSION:-}" in
    *" 93"*)
        alias local="typeset -x"
        ;;
    *)
        ;;
esac

# Make zsh emulate the Bourne shell
if [ -n "${ZSH_VERSION:-}" ]
then
    emulate sh
fi

# This is required to preserve the Windows drive letter in the
# path to HOME
case "$(uname)" in
    CYGWIN*)
        HOME="$(cygpath --mixed --windows "${HOME}")"
        ;;
    *)
        ;;
esac

# func <program>
program_is_available() {
    local program="${1}"

    assert test -n "${program}"

    command -v "${program}"
}

# func <port>
port_is_active() {
    local port="$1"

    assert program_is_available nc

    if nc -z localhost "${port}"
    then
        printf "Port %s is active
" "${port}"
        return 0
    else
        printf "Port %s is free
" "${port}"
        return 1
    fi
}

# func <port>
await_port_is_active() {
    local port="$1"
    local i=0

    log "Waiting for port ${port} to open"

    while ! port_is_active "${port}"
    do
        i=$((i + 1))

        if [ "${i}" = 30 ]
        then
            log "Timed out waiting for port ${port} to open"
            return 1
        fi

        sleep 2
    done
}

# func <port>
await_port_is_free() {
    local port="$1"
    local i=0

    log "Waiting for port ${port} to close"

    while port_is_active "${port}"
    do
        i=$((i + 1))

        if [ "${i}" = 30 ]
        then
            log "Timed out waiting for port ${port} to close"
            return 1
        fi

        sleep 2
    done
}

# func <string> <glob>
string_is_match() {
    local string="$1"
    local glob="$2"

    assert test -n "${glob}"

    # shellcheck disable=SC2254 # We want the glob
    case "${string}" in
        ${glob})
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

random_number() {
    printf "%s%s" "$(date +%s)" "$$"
}

# func <archive-file> <output-dir>
extract_archive() {
    local archive_file="$1"
    local output_dir="$2"

    assert test -f "${archive_file}"
    assert test -d "${output_dir}"
    assert program_is_available gzip
    assert program_is_available tar

    gzip -dc "${archive_file}" | (cd "${output_dir}" && tar xf -)
}

assert() {
    local location="$0:"

    # shellcheck disable=SC2128 # We want only the first element of the array
    if [ -n "${BASH_LINENO:-}" ]
    then
        location="$0:${BASH_LINENO}:"
    fi

    if ! "$@" > /dev/null 2>&1
    then
        printf "%s %s assert %s
" "$(red "ASSERTION FAILED:")" "$(yellow "${location}")" "$*" >&2
        exit 1
    fi
}

log() {
    printf -- "-- %s
" "$1"
}

run() {
    printf -- "-- Running '%s'
" "$*" >&2
    "$@"
}

bold() {
    printf "[1m%s[0m" "$1"
}

red() {
    printf "[1;31m%s[0m" "$1"
}

green() {
    printf "[0;32m%s[0m" "$1"
}

yellow() {
    printf "[0;33m%s[0m" "$1"
}

print() {
    if [ "$#" = 0 ]
    then
        printf "
" >&5
        printf -- "--
"
        return
    fi

    if [ "$1" = "-n" ]
    then
        shift

        printf "   %s" "$1" >&5
        printf -- "-- %s" "$1"
    else
        printf "   %s
" "$1" >&5
        printf -- "-- %s
" "$1"
    fi
}

print_section() {
    printf "== %s ==

" "$(bold "$1")" >&5
    printf "== %s
" "$1"
}

print_result() {
    printf "   %s

" "$(green "$1")" >&5
    log "Result: $(green "$1")"
}

fail() {
    printf "   %s %s

" "$(red "ERROR:")" "$1" >&5
    log "$(red "ERROR:") $1"

    if [ -n "${2:-}" ]
    then
        printf "   See %s

" "$2" >&5
        log "See $2"
    fi

    suppress_trouble_report=1

    exit 1
}

generate_password() {
    assert test -e /dev/urandom
    assert program_is_available head
    assert program_is_available tr

    head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 16
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

enable_debug_mode() {
    # Print the input commands and their expanded form to the console
    set -vx

    if [ -n "${BASH:-}" ]
    then
        # Bash offers more details
        export PS4='[0;33m${BASH_SOURCE}:${LINENO}:[0m ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
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
            printf "%s Something went wrong.

" "$(red "TROUBLE!")"
        else
            printf "   %s Something went wrong.

" "$(red "TROUBLE!")"
            printf "== Log ==

"

            sed -e "s/^/  /" < "${log_file}" || :

            printf "
"
        fi
    fi
}

# func <log-file> <verbose>
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
    #
    # XXX Use tee to capture to the log file at the same time?
    if [ -n "${verbose}" ]
    then
        exec 5> /dev/null
    else
        exec 6> "${log_file}"
    fi
}

# func [<dir>...]
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
            printf "Directory '%s' is writable
" "${base_dir}"
        else
            printf "Directory '%s' is not writeable
" "${base_dir}"
            unwritable_dirs="${unwritable_dirs}${base_dir}, "
        fi
    done

    if [ -n "${unwritable_dirs}" ]
    then
        fail "Some install directories are not writable: ${unwritable_dirs%??}" \
             "${troubleshooting_url}#some-install-directories-are-not-writable"
    fi
}

# func [<program>...]
check_required_programs() {
    log "Checking for required programs"

    local programs="$*"
    local program=
    local unavailable_programs=

    for program in ${programs}
    do
        log "Checking program '${program}'"

        if ! command -v "${program}"
        then
            unavailable_programs="${unavailable_programs}${program}, "
        fi
    done

    if [ -n "${unavailable_programs}" ]
    then
        fail "Some required programs are not available: ${unavailable_programs%??}" \
             "${troubleshooting_url}#some-required-programs-are-not-available"
    fi
}

check_required_program_sha512sum() {
    log "Checking for either 'sha512sum' or 'shasum'"

    if ! command -v sha512sum && ! command -v shasum
    then
        fail "Some required programs are not available: sha512sum or shasum" \
             "${troubleshooting_url}#some-required-programs-are-not-available"
    fi
}

# func [<port>...]
check_required_ports() {
    log "Checking for required ports"

    local ports="$*"
    local port=
    local unavailable_ports=

    for port in ${ports}
    do
        log "Checking port ${port}"

        if port_is_active "${port}"
        then
            unavailable_ports="${unavailable_ports}${port}, "
        fi
    done

    if [ -n "${unavailable_ports}" ]
    then
        fail "Some required ports are in use by something else: ${unavailable_ports%??}" \
             "${troubleshooting_url}#some-required-ports-are-in-use-by-something-else"
    fi
}

# func [<url>...]
check_required_network_resources() {
    log "Checking for required network resources"

    local urls="$*"
    local url=
    local unavailable_urls=

    assert program_is_available curl

    for url in ${urls}
    do
        log "Checking URL '${url}'"

        if ! curl -sf --show-error --head "${url}"
        then
            unavailable_urls="${unavailable_urls}${url}, "
        fi
    done

    if [ -n "${unavailable_urls}" ]
    then
        fail "Some required network resources are not available: ${unavailable_urls%??}" \
             "${troubleshooting_url}#some-required-network-resources-are-not-available"
    fi
}

check_java() {
    log "Checking the Java installation"

    if ! java --version
    then
        fail "Java is available, but it is not working" \
             "${troubleshooting_url}#java-is-available-but-it-is-not-working"
    fi
}

# func <backup-dir> <config-dir> <share-dir> <state-dir> [<bin-file>...]
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

        if [ -e "${artemis_bin_dir}/artemis" ]; then
            rm "${artemis_bin_dir}/artemis"
        fi

        if [ -e "${artemis_bin_dir}/artemis-service" ]; then
            rm "${artemis_bin_dir}/artemis-service"
        fi

        if [ -e "${artemis_config_dir}" ]; then
            rm -rf "${artemis_config_dir}"
        fi

        if [ -e "${artemis_home_dir}" ]; then
            rm -rf "${artemis_home_dir}"
        fi

        if [ -e "${artemis_instance_dir}" ]; then
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
