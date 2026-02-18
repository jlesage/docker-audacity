#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo ">>> $*"
}

AUDACITY_URL="$1"
AUDACITY_VERSION="$2"

if [ -z "$AUDACITY_URL" ]; then
    log "ERROR: Audacity URL missing."
    exit 1
fi

if [ -z "$AUDACITY_VERSION" ]; then
    log "ERROR: Audacity version missing."
    exit 1
fi

#
# Install required packages.
#
apk --no-cache add \
    curl \
    build-base \
    mold \
    llvm \
    clang \
    wxwidgets-dev \

#
# Download sources.
#

log "Downloading Audacity package..."
mkdir /tmp/audacity
curl -# -L -f ${AUDACITY_URL} | tar xz --strip 1 -C /tmp/audacity

#
# Compile Audacity.
#

log "Compiling Audiacious image-compiler..."
clang++ \
    -std=c++17 -Wall -Wextra \
    -DAUDACITY_VERSION_STRING="\"$AUDACITY_VERSION\"" \
    -DINSTALL_PREFIX='"/usr"' \
    -DwxDEBUG_LEVEL=0 \
    /tmp/audacity/libraries/image-compiler/imageCompilerMain.cpp \
    /tmp/audacity/libraries/lib-basic-ui/*.cpp \
    /tmp/audacity/libraries/lib-files/*.cpp \
    /tmp/audacity/libraries/lib-theme/*.cpp \
    /tmp/audacity/libraries/lib-preferences/*.cpp \
    /tmp/audacity/libraries/lib-strings/*.cpp \
    /tmp/audacity/libraries/lib-utility/*.cpp \
    /tmp/audacity/libraries/lib-exceptions/*.cpp \
    -DFILES_API= -DBASIC_UI_API= -DTHEME_API= -DPREFERENCES_API= \
    -DSTRINGS_API= -DUTILITY_API= -DEXCEPTIONS_API= \
    -I/tmp/audacity/libraries/lib-preferences \
    -I/tmp/audacity/libraries/lib-strings \
    -I/tmp/audacity/libraries/lib-exceptions/ \
    -I/tmp/audacity/libraries/lib-components \
    -I/tmp/audacity/libraries/lib-theme \
    -I/tmp/audacity/libraries/lib-utility \
    -I/tmp/audacity/libraries/lib-basic-ui \
    -I/tmp/audacity/libraries/lib-files \
    $(wx-config --cppflags) \
    $(wx-config --libs core) \
    -fuse-ld=mold -Wl,--strip-all -Wl,--as-needed \
    -o /tmp/image-compiler
