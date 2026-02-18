#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Set same default compilation flags as abuild.
export CFLAGS="-Os -fomit-frame-pointer"
export CFLAGS="$CFLAGS -w"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-fuse-ld=mold -latomic -Wl,--strip-all -Wl,--as-needed"

export CC=xx-clang
export CXX=xx-clang++

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() {
    echo ">>> $*"
}

AUDACITY_URL="$1"

if [ -z "$AUDACITY_URL" ]; then
    log "ERROR: Audacity URL missing."
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
    cmake \
    ninja \
    nasm  \
    patch \
    pkgconf \
    gettext \

# Needed to run the image-compiler tool, used by the build of Audacity..
apk --no-cache add \
    wxwidgets-gtk3 \

xx-apk --no-cache --no-scripts add \
    musl-dev \
    gcc \
    g++ \
    alsa-lib-dev \
    expat-dev \
    ffmpeg-dev \
    flac-dev \
    jack-dev \
    lame-dev \
    libid3tag-dev \
    libmad-dev \
    libogg-dev \
    libsndfile-dev \
    libvorbis-dev \
    lilv-dev \
    lv2-dev \
    mpg123-dev \
    opusfile-dev \
    portaudio-dev \
    portmidi-dev \
    rapidjson-dev \
    samurai \
    soundtouch-dev \
    soxr-dev \
    sqlite-dev \
    suil-dev \
    vamp-sdk-dev \
    wavpack-dev \
    wxwidgets-dev \
    zlib-dev \

# Fix cmake file for libjpeg-turbo detection.
if xx-info is-cross; then
    sed -i "s|/usr/|$(xx-info sysroot)usr/|" $(xx-info sysroot)usr/lib/cmake/libjpeg-turbo/libjpeg-turboTargets-none.cmake
fi

# Fix wxWidgets for cross-compile.
if xx-info is-cross; then
    # NOTE: wx-config is not found automatically because /usr/bin/wx-config is a
    #       symlink to /usr/lib/wx/config/gtk3-unicode-3.2, which means that the
    #       symlink is broken when installed under $(xx-info sysroot).

    # User our own wrapper, which just calls /usr/lib/wx/config/gtk3-unicode-3.2
    # with the added `--prefix=$(xx-info sysroot)usr` parameter.
    cp "$SCRIPT_DIR"/wx-config $(xx-info sysroot)usr/bin/
fi

#
# Download sources.
#

log "Downloading Audacity package..."
mkdir /tmp/audacity
curl -# -L -f ${AUDACITY_URL} | tar xz --strip 1 -C /tmp/audacity

#
# Compile Audacity.
#

log "Patching Audacity..."
patch -p1 -d /tmp/audacity < "$SCRIPT_DIR"/fix-owner-less.patch
patch -p1 -d /tmp/audacity < "$SCRIPT_DIR"/cmake-strip.patch
patch -p1 -d /tmp/audacity < "$SCRIPT_DIR"/fix-include.patch

log "Configuring Audacity..."
(
    arch_opts=
    case "$(xx-info arch)" in
        amd64)
            arch_oprts="-DHAVE_SSE=ON -DHAVE_SSE2=ON -DHAVE_MMX=ON"
            ;;
        *)
            arch_opts="-DHAVE_SSE=OFF -DHAVE_SSE2=OFF -DHAVE_MMX=OFF"
            ;;
    esac
    cd /tmp/audacity && \
        PKG_CONFIG_PATH=$(xx-info sysroot)usr/share/pkgconfig \
        cmake -B build -G Ninja -Wno-dev \
        $(xx-clang --print-cmake-defines) \
        -DCMAKE_STRIP=/usr/bin/$(xx-info)-strip \
        -DCMAKE_FIND_ROOT_PATH=$(xx-info sysroot) \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_FIND_DEBUG_MODE=OFF \
        -DAUDACITY_BUILD_LEVEL=2 \
        -DIMAGE_COMPILER_EXECUTABLE=/tmp/image-compiler \
        -Daudacity_conan_enabled=OFF \
        -Daudacity_has_vst3=OFF \
        -Daudacity_has_crashreports=OFF \
        -Daudacity_has_networking=OFF \
        -Daudacity_has_sentry_reporting=OFF \
        -Daudacity_has_updates_check=OFF \
        -Daudacity_has_whats_new=OFF \
        -Daudacity_lib_preference=system \
        -Daudacity_obey_system_dependencies=ON \
        -Daudacity_use_portsmf=local \
        -Daudacity_use_sbsms=local \
        -Daudacity_use_twolame=local \
        $arch_opts \
)

log "Compiling Audiacious..."
cmake --build /tmp/audacity/build

log "Installing Audacity..."
mkdir /tmp/audacity-install
DESTDIR=/tmp/audacity-install cmake --install /tmp/audacity/build
