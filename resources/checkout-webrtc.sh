#!/usr/bin/env bash
DEPOT_TOOLS_REPO="https://chromium.googlesource.com/chromium/tools/depot_tools.git"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <DEPOT_TOOLS_DIR> <WEBRTC_DIR> <REV>"
    echo "  DEPOT_TOOLS_DIR: Directory for Google depot tools (may exist already)"
    echo "  WEBRTC_DIR: Directory for WebRTC checkout (may exist already)"
    echo "  REV: Revision of WebRTC to check out"
    exit 1
fi;

set -e
export -n SHELLOPTS # Makes depot-tools fail

DEPOT_TOOLS_DIR=$1
WEBRTC_DIR=$2
REV=$3

# On Windows, even running under Git Bash, depot_tools needs its .bat wrappers:
# the plain fetch/gclient/update_depot_tools scripts are POSIX-only and bootstrap
# CIPD via a uname-based platform check ("windows-amd64") that has no pinned hash
# for it in depot_tools' digests file, so it fails before doing anything. The .bat
# wrappers bootstrap CIPD differently (via PowerShell) and work correctly.
if [ "$OS" = "Windows_NT" ]; then
    UPDATE_DEPOT_TOOLS=update_depot_tools.bat
    FETCH=fetch.bat
    GCLIENT=gclient.bat
else
    UPDATE_DEPOT_TOOLS=update_depot_tools
    FETCH=fetch
    GCLIENT=gclient
fi

STARTDIR=$PWD

if test -d "$DEPOT_TOOLS_DIR"; then
    if test \! -d "$DEPOT_TOOLS_DIR"/.git; then
        echo "ERROR: $DEPOT_TOOLS_DIR exists, but does not seem to be a Git repository"
        exit 1
    fi
    export PATH="$PATH:$DEPOT_TOOLS_DIR"
    "$UPDATE_DEPOT_TOOLS"
else
    parent="$(dirname "$DEPOT_TOOLS_DIR")"
    mkdir -p "$parent"
    cd "$parent"
    git clone "$DEPOT_TOOLS_REPO"
    export PATH="$PATH:$DEPOT_TOOLS_DIR"
    cd "$STARTDIR"
fi


# See if they specified the WebRTC src dir rather than its parent
if test "$(basename "$WEBRTC_DIR")" = "src"; then
    WEBRTC_DIR="$(dirname $WEBRTC_DIR)"
fi

if test -d "$WEBRTC_DIR"; then
    if test -r "$WEBRTC_DIR/.gclient"; then
        # Already existing gclient checkout; continue
        cd "$WEBRTC_DIR"
    elif test -n "$(ls -A "$WEBRTC_DIR")"; then
        echo "ERROR: $WEBRTC_DIR exists, does not seem to be a gclient checkout, but is non-empty"
        exit 1
    fi
else
    mkdir -p "$WEBRTC_DIR"
    cd "$WEBRTC_DIR"
    "$FETCH" --nohooks webrtc
fi

"$GCLIENT" sync -r $REV -D

