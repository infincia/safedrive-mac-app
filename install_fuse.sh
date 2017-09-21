#!/usr/bin/env bash

set -e

INSTALL_SOURCE=${BUNDLE:-"sdfuse.bundle"}
INSTALL_PATH="/Library/Filesystems/sdfuse.fs"

echo "Installing ${INSTALL_PATH} -> ${INSTALL_PATH}"

if [ -d "${INSTALL_PATH}" ]; then
    "${PWD}/uninstall_fuse.sh"
fi

sudo /bin/cp -av "${INSTALL_SOURCE}" "${INSTALL_PATH}"
sudo chmod +s "/Library/Filesystems/sdfuse.fs/Contents/Resources/load_sdfuse"
sudo chown -R root:wheel "/Library/Filesystems/sdfuse.fs/Contents/Extensions"
sudo chmod -R 755 "/Library/Filesystems/sdfuse.fs/Contents/Extensions"

/Library/Filesystems/sdfuse.fs/Contents/Resources/load_sdfuse
