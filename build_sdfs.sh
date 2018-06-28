#!/usr/bin/env bash

set -e -u -o pipefail # Fail on error

DIST_DIR=${PWD}/dist
BUILD_DIR=${PWD}/build

mkdir -p ${DIST_DIR}
mkdir -p ${BUILD_DIR}

rm -rf ${BUILD_DIR}/sdfs*
rm -rf ${DIST_DIR}/*

pushd sdfs
find . -name '*sdfs*' -exec rm -r {} \; || true
git submodule foreach git reset --hard
git reset --hard
popd

./patch_sdfs.sh || ./patch_sdfs.sh || ./patch_sdfs.sh || ./patch_sdfs.sh

pushd sdfs
./build.sh -v 5 -t fsbundle -a build -- -s 10.13 -d 10.9 --kext=10.9 --kext="10.10->10.9" --kext=10.11 --kext="10.12->10.11" --kext="10.13->10.11"
./build.sh -v 5 -t library -a build -- -s 10.13 -d 10.9
popd

ditto /tmp/sdfs/fsbundle/sdfs.fs ${DIST_DIR}/sdfs.bundle

pushd ${DIST_DIR}/sdfs.bundle/Contents/Extensions

popd

codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfs.bundle/Contents/Extensions/10.9/sdfs.kext
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfs.bundle/Contents/Extensions/10.11/sdfs.kext
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfs.bundle/Contents/Resources/mount_sdfs
codesign --verbose --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfs.bundle/Contents/Resources/load_sdfs
codesign --verbose --force --deep --sign "Developer ID Application: Stephen Oliver" ${DIST_DIR}/sdfs.bundle

codesign --verbose --verify ${DIST_DIR}/sdfs.bundle/Contents/Extensions/10.9/sdfs.kext
codesign --verbose --verify ${DIST_DIR}/sdfs.bundle/Contents/Extensions/10.11/sdfs.kext
codesign --verbose --verify ${DIST_DIR}/sdfs.bundle/Contents/Resources/mount_sdfs
codesign --verbose --verify ${DIST_DIR}/sdfs.bundle/Contents/Resources/load_sdfs
codesign --verbose --verify ${DIST_DIR}/sdfs.bundle

cp -a /tmp/sdfs/library/Source/lib/.libs/libsdfs.2.dylib ${DIST_DIR}/libsdfs.2.dylib
install_name_tool -id "@rpath/libsdfs.2.dylib" ${DIST_DIR}/libsdfs.2.dylib

cp -a /tmp/sdfs/library/Source/lib/.libs/libsdfs.2.dylib.dSYM ${DIST_DIR}/libsdfs.2.dSYM || true
