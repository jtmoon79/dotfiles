#!/usr/bin/env bash
#
# if WireGuard $iface cannot ping $host then restart the wireguard interface
#
# meant to be called from cron so manually logs a lot
#
# blunt but useful way to try to keep the wireguard connection wg1 up
# ... it goes down every few days for no apparent reason

set -eu

if [[ ${#} -ne 2 ]]; then
    echo "usage: ${0} iface host" >&2
    echo >&2
    echo "example:" >&2
    echo "${0} wg1 10.0.0.2" >&2
    exit 1
fi

iface=${1}
host=${2}

bname=$(basename "${0}")
bname_noe=${bname%.*}

function log () {
    logger -i -t "${bname_noe}" -s
}

function exit_ () {
    echo -n "done" | log
}
trap exit_ EXIT

echo -n "${PS4}${0} ${*}" | log

if ! wg show "${iface}" &>/dev/null; then
    echo -n "interface ${iface} is down" | log
    exit 0
fi

function ping_host () {
    declare out=
    out=$(
        set -x
        ping -n -I "${iface}" -c 1 -W 2 -q "${host}"
    ) 2>&1
    declare -ir ret=$?
    echo -n "${out}" | log
    if [[ ${ret} -ne 0 ]]; then
        # if the ping failed, wait 5 seconds
        sleep 5
    fi
    return ${ret}
}

# try three times
if ! ( \
    ping_host \
    || ping_host \
    || ping_host \
); then
    echo "ping ${host} using ${iface} failed" | log
    (
        set -x
        systemctl restart wg-quick@${iface}.service
    ) 2>&1 | log
fi
