# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# devbuild compiles the binary
# -----------------------------------
FROM golang:1.22 AS devbuild

WORKDIR /build
COPY . ./
RUN make

# dev runs the binary from devbuild
# -----------------------------------
FROM alpine:3.19.1 AS dev

COPY --from=devbuild /build/nomad-load /bin/
