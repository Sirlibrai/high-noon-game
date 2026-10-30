#!/bin/sh
# Builds the HighNoonCloud static library for iPhone (arm64). Needs Xcode.
set -e
cd "$(dirname "$0")"
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.0 -fobjc-arc -O2 -c HighNoonCloud.mm -o HighNoonCloud.o
xcrun -sdk iphoneos libtool -static -o HighNoonCloud.a HighNoonCloud.o
cp HighNoonCloud.a HighNoonCloud.release.a
cp HighNoonCloud.a HighNoonCloud.debug.a
rm HighNoonCloud.o
echo "Built HighNoonCloud.a"
