#!/usr/bin/env bash

# `before_deploy` phase: here we package the build artifacts

set -ex

. $(dirname $0)/utils.sh

mk_tarball() {
    pushd update
    tar -zcf ../${PROJECT_NAME}-${TRAVIS_TAG}-${TARGET}.tar.gz *
    popd
}

main() {
    mk_tarball
}

main
