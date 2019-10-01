FROM golang:1.12.9-alpine3.10 AS build

ENV BUILDAH_VER=1.10.1
RUN apk update \
    && \
    apk add --no-cache \
        gcc \
        musl-dev \
        libassuan-dev \
        libc-dev \
        gpgme-dev \
        libseccomp-dev \
        libselinux-dev \
        ostree-dev \
        btrfs-progs-dev \
        lvm2-dev \
    && \
    wget -O buildah.zip "https://github.com/containers/buildah/archive/v${BUILDAH_VER}.zip" \
    && \
    unzip buildah.zip \
    && \
    mkdir -p src/github.com/containers/ \
    && \
    mv "buildah-${BUILDAH_VER}" src/github.com/containers/buildah
WORKDIR src/github.com/containers/buildah
RUN GO111MODULE=on go build -mod=vendor -o buildah ./cmd/buildah

ENV LIBFUSE_VER=3.5.0
WORKDIR /
RUN apk add --no-cache \
        make \
        automake \
        autoconf \
        meson \
        clang \
        eudev-dev \
        ninja \
    && \
    wget -O libfuse.zip "https://github.com/libfuse/libfuse/archive/fuse-${LIBFUSE_VER}.zip" \
    && \
    unzip libfuse.zip \
    && \
    mv "libfuse-fuse-${LIBFUSE_VER}" libfuse-fuse \
    && \
    mkdir build
WORKDIR libfuse-fuse/build
RUN LDFLAGS="-lpthread" meson --prefix /usr -D default_library=static .. \
    && \
    ninja \
    && \
    ninja install

ENV FUSE_OVERLAY_VER=0.6.2
WORKDIR /
RUN wget -O fuse-overlayfs.zip "https://github.com/containers/fuse-overlayfs/archive/v${FUSE_OVERLAY_VER}.zip" \
    && \
    unzip fuse-overlayfs.zip \
    && \
    mv "fuse-overlayfs-${FUSE_OVERLAY_VER}" fuse-overlayfs
WORKDIR fuse-overlayfs
RUN sh autogen.sh \
    && \
    LIBS="-ldl" LDFLAGS="-static" ./configure --prefix /usr \
    && \
    make \
    && \
    make install

FROM alpine:3.10

COPY --from=build /go/src/github.com/containers/buildah/buildah /
COPY --from=build /usr/bin/fuse-overlayfs /usr/local/bin/fuse-overlayfs
COPY registries.conf /etc/containers/
COPY policy.json /etc/containers/
COPY storage.conf /etc/containers/

RUN apk update \
    && \
    apk add --no-cache \
      gpgme \
      lvm2 \
      ca-certificates \
    && \
    wget -O /usr/bin/runc https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
    && \
    chmod +x /usr/bin/runc

ENTRYPOINT ["/buildah"]
