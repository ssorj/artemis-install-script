#!/usr/bin/bats

@test program_functions {
    source burly.sh

    program_is_available cat
    ! program_is_available not-there
}

@test port_functions {
    source burly.sh

    # ncat --chat --listen localhost 55552 &
    # trap "kill $! || :" EXIT
    #
    # await_port_is_active 55552

    await_port_is_free 55555
}

@test string_functions {
    source burly.sh

    string_is_match a a
    string_is_match a a\*
    string_is_match a \*
    string_is_match a \?
    ! string_is_match a b
    ! string_is_match a b\*
    ! string_is_match a a\?
}

@test generate_functions {
    source burly.sh

    first=$(random_number)
    sleep 1
    second=$(random_number)

    [ "$first" != "$second" ]

    generate_password
}

@test archive_functions {
    source burly.sh

    input_dir=$(mktemp -d)
    output_dir=$(mktemp -d)

    mkdir "${input_dir}/archive"
    echo "hello" > "${input_dir}/archive/hello.txt"

    (
        cd "$input_dir"
        tar -cvf archive.tar archive
        gzip archive.tar
    )

    extract_archive "${input_dir}/archive.tar.gz" "$output_dir"

    [ $(cat "${output_dir}/archive/hello.txt") == "hello" ]
}

@test script_init_functions {
    source burly.sh

    enable_strict_mode

    init_logging $(mktemp) 1

    {
        :
    } >&6 2>&6
}

@test print_functions {
    source burly.sh

    enable_strict_mode

    init_logging $(mktemp) 1

    {
        assert true

        log hello

        run echo hello

        print
        print -n hello
        print hello
        print $(red hello)
        print $(yellow hello)
        print $(green hello)

        print_section section1
        print_result result
    } 6> /dev/null >&6 2>&6
}

@test check_functions {
    source burly.sh

    enable_strict_mode

    init_logging $(mktemp) 1

    {
        check_writable_directories $HOME
        check_required_programs cat
        # check_required_program_sha512sum
        check_required_ports 55555
        check_required_network_resources https://example.net/
        check_java
    } >&6 2>&6
}

@test save_backup {
    source burly.sh

    init_logging $(mktemp) 1

    {
        save_backup $(mktemp -d) $(mktemp -d) $(mktemp -d) $(mktemp -d)
    } >&6 2>&6
}
