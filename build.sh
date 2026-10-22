#!/bin/sh
# Builds "build/Bag of Holding.app" from source, sandboxed and signed ad hoc.
set -eu
cd "$(dirname "$0")"
swift build -c release --product BagOfHolding
app="build/Bag of Holding.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/BagOfHolding "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
codesign --force --sign - --options runtime --entitlements BagOfHolding.entitlements "$app"
echo "Built $app"
