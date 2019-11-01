FROM golang:1.12.9-alpine3.10 AS build

ENV BUILDAH_VER=1.11.4

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

FROM alpine:3.10

COPY --from=build /go/src/github.com/containers/buildah/buildah /
COPY registries.conf /etc/containers/
COPY policy.json /etc/containers/

RUN apk update \
    && \
    apk add --no-cache \
      gpgme \
      lvm2 \
      ca-certificates \
    && \
    wget -O /usr/bin/runc https://github.com/opencontainers/runc/releases/download/v1.0.0-rc9/runc.amd64 \
    && \
    chmod +x /usr/bin/runc

ENTRYPOINT ["/buildah"]
