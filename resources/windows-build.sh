#!/usr/bin/env bash
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <JAVA_HOME> <WEBRTC_DIR> <MSVC_DIR> <ARCH>"
    echo "  JAVA_HOME: Path to a (Linux) Java installation, used to run mvn/javac and for jni.h"
    echo "  WEBRTC_DIR: Directory containing WebRTC source"
    echo "  MSVC_DIR: Directory of the msvc-wine MSVC/WinSDK install (the <dir> passed to install.sh)"
    echo "  ARCH: Architecture to build for (x86_64 or arm64)"
    exit 1
fi

set -e
export -n SHELLOPTS

JAVA_HOME=$1
WEBRTC_DIR=$2
MSVC_DIR=$3
ARCH=$4

case $ARCH in
    "x86-64"|"x86_64"|"amd64"|"x64")
        JNAARCH=x86-64
        MSVCARCH=x64
        ;;
    "arm64"|"aarch64")
        JNAARCH=aarch64
        MSVCARCH=arm64
        ;;
    *)
	echo "ERROR: Unsupported arch $ARCH"
	exit 1
	;;
esac

if test \! -d $WEBRTC_DIR/.git -a -r $WEBRTC_DIR/.gclient -a -d $WEBRTC_DIR/src/.git; then
    # They specified the WebRTC gclient directory, not the src checkout subdirectory
    WEBRTC_DIR=$WEBRTC_DIR/src
fi

WEBRTC_BUILD=out/windows-$MSVCARCH
WEBRTC_OBJ=$WEBRTC_DIR/$WEBRTC_BUILD

export PATH="$MSVC_DIR/bin/$MSVCARCH:$PATH"

NCPU=$(nproc)
if [ -n "$NCPU" -a "$NCPU" -gt 1 ]
then
    MAKE_ARGS="-j $NCPU"
fi

startdir=$PWD

# "gn"/ninja doesn't support cross-compiling WebRTC for Windows from a non-Windows host,
# so build libdcsctp.a directly with cl.exe/lib.exe, the same way resources/Makefile does
# for ppc64le (where "gn" also has no support). See resources/Makefile.windows.
make $MAKE_ARGS -C "$startdir/resources" \
    -f Makefile.windows \
    VPATH="$WEBRTC_DIR" \
    OBJDIR="$WEBRTC_OBJ/obj" \
    CXX=cl \
    AR=lib

if [ -n "$MAKE_ARGS" ]
then
    CMAKE_BUILD_ARGS=" -- $MAKE_ARGS"
fi

rm -rf cmake-build-windows-"$JNAARCH"
CC=cl CXX=cl cmake -B cmake-build-windows-"$JNAARCH" \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DJAVA_HOME="$JAVA_HOME" \
    -DCMAKE_INSTALL_PREFIX="src/main/resources/windows-$JNAARCH" \
    -DWEBRTC_DIR="$WEBRTC_DIR" \
    -DWEBRTC_OBJ="$WEBRTC_OBJ" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo

cmake --build cmake-build-windows-"$JNAARCH" --target install $CMAKE_BUILD_ARGS
