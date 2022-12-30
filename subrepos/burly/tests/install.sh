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

troubleshooting_url="https://github.com/ssorj/burly/blob/main/troubleshooting.md"

# Make the local keyword work with ksh93 and POSIX-style functions
case "${KSH_VERSION:-}" in
    *" 93"*)
        alias local="typeset -x"
        ;;
    *)
        ;;
esac

. ./burly.sh

# func <url-path> <output-dir> -> release_version=<version>, release_file=<file>
fetch_latest_apache_release() {
    local url_path="$1"
    local output_dir="$2"

    assert string_is_match "${url_path}" "/*/"
    assert test -d "${output_dir}"
    assert program_is_available curl
    assert program_is_available awk
    assert program_is_available sort
    assert program_is_available tail
    program_is_available sha512sum || program_is_available shasum || assert false

    local release_version_file="${output_dir}/release-version.txt"

    log "Looking up the latest release version"

    run curl -sf --show-error "https://dlcdn.apache.org${url_path}" \
        | awk 'match($0, /[0-9]+\.[0-9]+\.[0-9]+/) { print substr($0, RSTART, RLENGTH) }' \
        | sort -t . -k1n -k2n -k3n \
        | tail -n 1 >| "${release_version_file}"

    release_version="$(cat "${release_version_file}")"

    printf "Release version: %s\n" "${release_version}"
    printf "Release version file: %s\n" "${release_version_file}"

    local release_file_name="apache-artemis-${release_version}-bin.tar.gz"
    release_file="${output_dir}/${release_file_name}"
    local release_file_checksum="${release_file}.sha512"

    if [ ! -e "${release_file}" ]
    then
        log "Downloading the latest release"

        run curl -sf --show-error -o "${release_file}" \
            "https://dlcdn.apache.org${url_path}${release_version}/${release_file_name}"
    else
        log "Using the cached release archive"
    fi

    printf "Archive file: %s\n" "${release_file}"

    log "Downloading the checksum file"

    run curl -sf --show-error -o "${release_file_checksum}" \
        "https://downloads.apache.org${url_path}${release_version}/${release_file_name}.sha512"

    printf "Checksum file: %s\n" "${release_file_checksum}"

    log "Verifying the release archive"

    if command -v sha512sum
    then
        if ! run sha512sum -c "${release_file_checksum}"
        then
            fail "The checksum does not match the downloaded release archive" \
                 "${troubleshooting_url}#the-checksum-does-not-match-the-downloaded-release-archive"
        fi
    elif command -v shasum
    then
        if ! run shasum -a 512 -c "${release_file_checksum}"
        then
            fail "The checksum does not match the downloaded release archive" \
                 "${troubleshooting_url}#the-checksum-does-not-match-the-downloaded-release-archive"
        fi
    else
        assert false
    fi

    assert test -n "${release_version}"
    assert test -f "${release_file}"
}

main() {
    enable_strict_mode

    if [ -n "${DEBUG:-}" ]
    then
        enable_debug_mode
    fi

    local verbose=

    local artemis_bin_dir="${HOME}/.local/bin"
    local artemis_config_dir="${HOME}/.config/artemis"
    local artemis_home_dir="${HOME}/.local/share/artemis"
    local artemis_instance_dir="${HOME}/.local/state/artemis"

    local work_dir="${HOME}/test-install-script"
    local log_file="${work_dir}/install.log"
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

        check_writable_directories "${artemis_bin_dir}" \
                                   "$(dirname "${artemis_config_dir}")" \
                                   "$(dirname "${artemis_home_dir}")" \
                                   "$(dirname "${artemis_instance_dir}")"

        check_required_programs awk curl gzip java nc ps sed tar

        check_required_program_sha512sum

        check_required_ports 1883 5672 8161 61613 61616

        check_required_network_resources "https://dlcdn.apache.org/" "https://downloads.apache.org/"

        check_java

        print_result "OK"

        print_section "Downloading and verifying the latest release"

        fetch_latest_apache_release "/activemq/activemq-artemis/" "${work_dir}"

        print_result "OK"

        if [ -e "${artemis_config_dir}" ] || [ -e "${artemis_home_dir}" ] || [ -e "${artemis_instance_dir}" ]
        then
            print_section "Saving the existing installation to a backup"

            save_backup "${backup_dir}" \
                        "${artemis_config_dir}" "${artemis_home_dir}" "${artemis_instance_dir}" \
                        "${artemis_bin_dir}/artemis" "${artemis_bin_dir}/artemis-service"

            print_result "OK"
        fi

        print_section "Installing the broker"

        log "Extracting the release dir from the release archive"

        local release_dir="${work_dir}/apache-artemis-${release_version}"

        extract_archive "${release_file}" "${work_dir}"

        assert test -d "${release_dir}"

        log "Moving the release dir to its install location"

        assert test ! -e "${artemis_home_dir}"

        mkdir -p "$(dirname "${artemis_home_dir}")"
        mv "${release_dir}" "${artemis_home_dir}"

        log "Creating the broker instance"

        local password
        password="$(generate_password)"

        run "${artemis_home_dir}/bin/artemis" create "${artemis_instance_dir}" \
            --user example --password "${password}" \
            --host localhost --allow-anonymous \
            --no-autotune \
            --no-hornetq-acceptor \
            --etc "${artemis_config_dir}" \
            --verbose

        print_result "OK"
    } >&6 2>&6
}

main "$@"
