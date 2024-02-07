#!/usr/bin/env bash

set -ex -o

DIR=$1

read -ra server_ips <<< "$2"
read -ra client_ips <<< "$3"

if [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
fi

pushd "$DIR"

nomad tls ca create

nomad tls cert create \
  -server \
  "${server_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create \
  -client \
  "${client_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create -cli

popd
