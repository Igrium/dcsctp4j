#!/usr/bin/env bash
PROJECT_DIR="$(realpath "$(dirname "$0")/../")"
JAVA_VERSION=11
ARCHS=(x86-64 arm64)

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <DEPOT_TOOLS_DIR> <WEBRTC_DIR> <MSVC_DIR>"
    echo "  DEPOT_TOOLS_DIR: Directory containing Google depot tools"
    echo "  WEBRTC_DIR: Directory containing WebRTC source"
    echo "  MSVC_DIR: Directory of the msvc-wine MSVC/WinSDK install (the <dir> passed to install.sh)"
    exit 1
fi

set -e
export SHELLOPTS

DEPOT_TOOLS_DIR=$1
WEBRTC_DIR=$2
MSVC_DIR=$3

WEBRTC_REVISION="$(<$PROJECT_DIR/resources/WebRTC-revision.txt)"

if [ -z "$WEBRTC_REVISION" ]; then
    echo "Could not find WebRTC revision"
    exit 1
fi

if [ -z "$JAVA_HOME" ]; then
    NATIVEDEBARCH=$(dpkg --print-architecture)
    JAVA_HOME=/usr/lib/jvm/java-$JAVA_VERSION-openjdk-$NATIVEDEBARCH
fi

if [ -z "$JAVA_HOME" ]; then
    echo "Could not find Java home; set JAVA_HOME in the environment,"
    echo "or install it in /usr/lib/jvm."
    exit 1
fi

mvn compile # Build SimpleJNI jnigen headers

"$PROJECT_DIR/resources/checkout-webrtc.sh" "$DEPOT_TOOLS_DIR" "$WEBRTC_DIR" "$WEBRTC_REVISION"

for ARCH in "${ARCHS[@]}"; do
    "$PROJECT_DIR/resources/windows-build.sh" "$JAVA_HOME" "$WEBRTC_DIR" "$MSVC_DIR" "$ARCH"
done
