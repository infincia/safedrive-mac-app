#!/bin/sh

set -e

pushd sdfuse

files=("*.c" "*.h" "*.m" "*Info.plist" "*version.plist" "*.pbxproj" "*.sh" "*.am" "*.ac" "*.d" "*.in")
for i in "${files[@]}"
do
echo "Files: $i"
find . -name "$i" -type f
find . -name "$i" -type f -exec sed -i '' s/osxfuse/sdfuse/g {} +
find . -name "$i" -type f -exec sed -i '' s/OSXFUSE/SDFUSE/g {} +
find . -name "$i" -type f -exec sed -i '' s/com.github/io.safedrive/g {} +
find . -name "$i" -type f -exec sed -i '' s/.filesystems.sdfuse//g {} +
done

find . -type d -name '*osxfuse*' -exec sh -c 'mv {} $(echo {} | sed -e 's/osxfuse/sdfuse/g')' \;
find . -name '*osxfuse*' -exec sh -c 'mv {} $(echo {} | sed -e 's/osxfuse/sdfuse/g')' \; || true

popd
