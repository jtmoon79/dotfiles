#!/usr/bin/env bash
#
# print CPU temperature in Centigrade
# ripped from https://askubuntu.com/a/854029/368900
#

set -euo pipefail

if ! which paste column sed &>/dev/null; then
    echo 'ERROR missing necessary programs' >&2
    exit 1
fi

if ! ls -d1 /sys/class/thermal/thermal_zone* &>/dev/null; then
    echo 'ERROR no system files found "/sys/class/thermal/thermal_zone*"' >&2
    exit 1
fi

command -p paste \
    <(cat -- /sys/class/thermal/thermal_zone*/type) \
    <(cat -- /sys/class/thermal/thermal_zone*/temp) \
    | command -p column -s $'\t' -t \
    | command -p sed -e 's/\(.\)..$/.\1°C/'
