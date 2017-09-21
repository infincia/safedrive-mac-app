#!/usr/bin/env bash

set -e -u -o pipefail # Fail on error

DIST_DIR=${PWD}/dist
BUILD_DIR=${PWD}/build

mkdir -p ${DIST_DIR}
mkdir -p ${BUILD_DIR}

rm -rf ${BUILD_DIR}/sdfuse*
rm -rf ${DIST_DIR}/*

./patch_fuse.sh || ./patch_fuse.sh || ./patch_fuse.sh || ./patch_fuse.sh

pushd sdfuse
./build.sh -v 5 -t fsbundle -a build -- -s 10.13 -d 10.9 --kext=10.9 --kext="10.10->10.9" --kext=10.11 --kext="10.12->10.11" --kext="10.13->10.11"
./build.sh -v 5 -t library -a build -- -s 10.13 -d 10.9
popd

ditto /tmp/sdfuse/fsbundle/sdfuse.fs ${DIST_DIR}/sdfuse.bundle

pushd ${DIST_DIR}/sdfuse.bundle/Contents/Extensions

popd

codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfuse.bundle/Contents/Extensions/10.9/sdfuse.kext
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfuse.bundle/Contents/Extensions/10.11/sdfuse.kext
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfuse.bundle/Contents/Resources/mount_sdfuse
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfuse.bundle/Contents/Resources/load_sdfuse
codesign --verbose --force --deep --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfuse.bundle

codesign --verbose --verify ${DIST_DIR}/sdfuse.bundle/Contents/Extensions/10.9/sdfuse.kext
codesign --verbose --verify ${DIST_DIR}/sdfuse.bundle/Contents/Extensions/10.11/sdfuse.kext
codesign --verbose --verify ${DIST_DIR}/sdfuse.bundle/Contents/Resources/mount_sdfuse
codesign --verbose --verify ${DIST_DIR}/sdfuse.bundle/Contents/Resources/load_sdfuse
codesign --verbose --verify ${DIST_DIR}/sdfuse.bundle

cp -a /tmp/sdfuse/library/Source/lib/.libs/libsdfuse.2.dylib ${DIST_DIR}/libsdfuse.2.dylib
install_name_tool -id "@rpath/libsdfuse.2.dylib" ${DIST_DIR}/libsdfuse.2.dylib

