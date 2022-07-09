#!/usr/bin/env bash
#
# run nmap to scan all ports on a host, run this as root

set -eux

exec nmap -v --privileged --open -p1-65535 "${@}"
