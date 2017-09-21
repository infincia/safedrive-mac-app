#!/usr/bin/env bash

set -e

INSTALL_PATH="/Library/Filesystems/sdfuse.fs"

sudo kextunload -b "io.safedrive.sdfuse" || true

if [ -d "${INSTALL_PATH}" ]; then
    sudo rm -rf "${INSTALL_PATH}"
fi
