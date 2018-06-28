#!/bin/sh

set -e

pushd sdfs

files=("*.c" "*.h" "*.m" "*Info.plist" "*version.plist" "*.pbxproj" "*.sh" "*.am" "*.ac" "*.d" "*.in")
for i in "${files[@]}"
do
echo "Files: $i"
find . -name "$i" -type f -exec sed -i '' s/osxfuse/sdfs/g {} +
find . -name "$i" -type f -exec sed -i '' s/OSXFUSE/SDFS/g {} +
find . -name "$i" -type f -exec sed -i '' s/com.github/io.safedrive/g {} +
find . -name "$i" -type f -exec sed -i '' s/.filesystems.sdfs//g {} +
done

find . -type d -name '*osxfuse*' -exec sh -c 'mv {} $(echo {} | sed -e 's/osxfuse/sdfs/g')' \; || true
find . -name '*osxfuse*' -exec sh -c 'mv {} $(echo {} | sed -e 's/osxfuse/sdfs/g')' \; || true

popd
