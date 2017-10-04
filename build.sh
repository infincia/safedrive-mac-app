#!/usr/bin/env bash

set -e

DATE=$(date -u)

SCHEMES=("STAGING" "RELEASE")
DEVELOPMENT_TEAM=G738Z89QKM
CODE_SIGN_IDENTITY="Developer ID Application"
VERSION=$(git describe --dirty)
BUILD=$(git rev-list --count HEAD)

rm -rf ./update/mac
mkdir -p ./update/mac

pod install

for SCHEME in "${SCHEMES[@]}"; do

LOWER_SCHEME=$(echo ${SCHEME} | awk '{print tolower($0)}')

echo "Building ${SCHEME} for macOS"

xcodebuild clean

xcodebuild archive -quiet -workspace SafeDrive.xcworkspace -scheme SafeDrive-${SCHEME} -derivedDataPath ./${LOWER_SCHEME} -archivePath ./${SCHEME}/SafeDrive-${SCHEME}.xcarchive

echo "Copying ${SCHEME} artifacts for macOS"

xcodebuild -quiet -exportArchive -archivePath ./${LOWER_SCHEME}/SafeDrive-${SCHEME}.xcarchive -exportPath ./${LOWER_SCHEME} -exportOptionsPlist exportOptions.plist

echo "Building archive"


ditto -c -k --sequesterRsrc --keepParent ./${LOWER_SCHEME}/SafeDrive.app update/mac/SafeDrive_${SCHEME}_${VERSION}.zip

FILESIZE=$(stat -f%z update/mac/SafeDrive_${SCHEME}_${VERSION}.zip)

echo "Creating update manifest"

echo "Size: $FILESIZE"

echo "Version: $VERSION ($BUILD)"


PLIST=$(cat <<EOF
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
<channel>
<title>SafeDrive Changelog</title>
<link>https://cdn.infincia.com/safedrive/${LOWER_SCHEME}.xml</link>
<description>Most recent changes</description>
<language>en</language>
<item>
<title>Version $VERSION</title>
<sparkle:minimumSystemVersion>10.9.0</sparkle:minimumSystemVersion>
<description>
<![CDATA[
<ul> <li>See changelog in app</li> </ul>
]]>
</description>
<pubDate>$DATE</pubDate>
<enclosure url="https://cdn.infincia.com/safedrive/SafeDrive_${SCHEME}_$VERSION.zip" sparkle:shortVersionString="$VERSION" sparkle:version="$BUILD" length="$FILESIZE" type="application/octet-stream"/>
</item>
</channel>
</rss>
EOF)

echo $PLIST > ./update/mac/${LOWER_SCHEME}.xml

done


