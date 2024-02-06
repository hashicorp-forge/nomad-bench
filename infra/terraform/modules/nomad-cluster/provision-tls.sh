#!/usr/bin/env bash

set -ex -o

project=$1
read -ra server_ips <<< "$2"
read -ra client_ips <<< "$3"

directory="./.tls-${project}"

if [ ! -d $directory ]; then
mkdir $directory
fi

pushd $directory

nomad tls ca create

nomad tls cert create \
-server \
"${server_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create \
-client \
"${client_ips[@]/#/--additional-ipaddress=}"

nomad tls cert create -cli

popd
