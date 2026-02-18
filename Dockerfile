#
# audacity Dockerfile
#
# https://github.com/jlesage/docker-audacity
#

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=

# Define software versions.
ARG AUDACITY_VERSION=3.7.7

# Define software download URLs.
ARG AUDACITY_URL=https://github.com/audacity/audacity/archive/refs/tags/Audacity-${AUDACITY_VERSION}.tar.gz

# Get Dockerfile cross-compilation helpers.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Build Audacity image-compiler.
FROM --platform=$BUILDPLATFORM alpine:3.20 AS audacity-image-compiler
ARG AUDACITY_URL
ARG AUDACITY_VERSION
COPY src/audacity-image-compiler /build
RUN /build/build.sh "$AUDACITY_URL" "$AUDACITY_VERSION"

# Build Audacity.
FROM --platform=$BUILDPLATFORM alpine:3.20 AS audacity
ARG TARGETPLATFORM
ARG AUDACITY_URL
COPY --from=xx / /
COPY --from=audacity-image-compiler /tmp/image-compiler /tmp/
COPY src/audacity /build
RUN /build/build.sh "$AUDACITY_URL"
RUN xx-verify \
    /tmp/audacity-install/usr/bin/audacity

# Pull base image.
FROM jlesage/baseimage-gui:alpine-3.20-v4.11.0

ARG AUDACITY_VERSION
ARG DOCKER_IMAGE_VERSION

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN add-pkg \
        adwaita-icon-theme \
        wxwidgets-gtk3 \
        libatomic \
        # For virtual ALSA device.
        alsa-plugins-pulse \
        # Audio codecs.
        ffmpeg-libavformat \
        libflac++ \
        libid3tag \
        libsndfile \
        lilv-libs \
        mpg123-libs \
        opusfile \
        portaudio \
        portmidi \
        soundtouch \
        soxr \
        sqlite-libs \
        suil \
        vamp-sdk-libs \
        wavpack-libs \
        # A font is needed.
        font-croscore

# Generate and install favicons.
RUN \
    APP_ICON_URL=https://raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/audacity-icon.png && \
    install_app_icon.sh "$APP_ICON_URL"

# Add files.
COPY rootfs/ /
COPY --from=audacity /tmp/audacity-install /

# Set internal environment variables.
RUN \
    set-cont-env APP_NAME "Audacity" && \
    set-cont-env APP_VERSION "$AUDACITY_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

# Set public environment variables.
ENV \
    WEB_AUDIO=1

# Define mountable directories.
VOLUME ["/storage"]

# Metadata.
LABEL \
      org.label-schema.name="audacity" \
      org.label-schema.description="Docker container for Audacity" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-audacity" \
      org.label-schema.schema-version="1.0"
