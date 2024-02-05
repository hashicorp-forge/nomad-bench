#!/usr/bin/env bash

set -ex -o

read -ra server_ips <<< "$1"
read -ra client_ips <<< "$2"

if [ ! -d "./.tls" ]; then
mkdir ./.tls
fi

pushd ./.tls

nomad tls ca create

nomad tls cert create \
-server \
"${server_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create \
-client \
"${client_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create -cli

popd
