# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# devbuild compiles the binary
# -----------------------------------
FROM golang:1.25 AS devbuild

WORKDIR /build
COPY . ./
RUN make build

# dev runs the binary from devbuild
# -----------------------------------
FROM alpine:3.23 AS dev

COPY --from=devbuild /build/nomad-raft-load /bin/

ENTRYPOINT ["/bin/nomad-raft-load"]
