#!/bin/bash
# Renders the main window, splash and help views to build/snapshots/*.png
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/snapshots
APP_SOURCES=$(ls Sources/App/*.swift | grep -v CurlToCodeApp.swift)
swiftc -parse-as-library Sources/Core/*.swift Sources/Core/Generators/*.swift $APP_SOURCES Scripts/snapshot.swift -o build/snapshot
./build/snapshot build/snapshots
