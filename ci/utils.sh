#!/usr/bin/env bash

mktempd() {
    echo $(mktemp -d 2>/dev/null || mktemp -d -t tmp)
}

host() {
    case "${TRAVIS_OS_NAME}" in
        linux)
            echo x86_64-unknown-linux-gnu
            ;;
        osx)
            echo x86_64-apple-darwin
            ;;
    esac
}
