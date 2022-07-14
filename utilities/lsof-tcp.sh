#!/usr/bin/env bash
#
# list TCP and UDP ports in-use

set -eux

exec lsof -PVn -iTCP -iUDP "${@}"
