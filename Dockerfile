# Forked-build of coredns/coredns into a 4-arch openweft image
# (linux/amd64 + arm64 + riscv64 + loong64). Upstream already ships
# amd64/arm/arm64/ppc64le/riscv64/s390x ; we add loong64 and re-publish
# under ghcr.io/openweft/weft-coredns so the openweft cluster's egress
# cache treats it the same as the other infra images.

ARG COREDNS_VERSION=v1.11.3
ARG GO_VERSION=1.23

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder
ARG COREDNS_VERSION TARGETOS TARGETARCH
WORKDIR /src
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates make && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 --branch=${COREDNS_VERSION} https://github.com/coredns/coredns.git .
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
# `make coredns` is the upstream entrypoint ; it runs `go gen` over
# plugin.cfg + `go build`. We pass GOOS/GOARCH through.
RUN make coredns BINARY=/out/coredns LDFLAGS="-s -w" SYSTEM="GOOS=${TARGETOS} GOARCH=${TARGETARCH}"

FROM scratch
ARG COREDNS_VERSION
LABEL org.opencontainers.image.title="weft-coredns" \
      org.opencontainers.image.description="openweft 4-arch build of coredns/coredns (adds loong64 vs upstream)" \
      org.opencontainers.image.version="${COREDNS_VERSION}" \
      org.opencontainers.image.source="https://github.com/openweft/weft-coredns" \
      org.opencontainers.image.url="https://github.com/openweft/weft-coredns" \
      org.opencontainers.image.licenses="Apache-2.0"
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/coredns /usr/local/bin/coredns
EXPOSE 53 53/udp
ENTRYPOINT ["/usr/local/bin/coredns"]
