#!/usr/bin/env bash
#
# crude script to visually monitor a network connection over a long
# period of time using ICMP ping
#
# XXX: for GNU date, %s is seconds, %N is subsecond nanoseconds
#
# looks like
# 21:19:18                   ꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏXꞏXꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏX
# 21:20:00 ꞏꞏꞏꞏꞏꞏꞏꞏꞏXꞏꞏꞏXꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏXꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏ
# 21:21:00 ꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏꞏ

set -eu

if [[ ${#} -lt 1 ]]; then
    echo "usage:
    ${0} HOSTNAME" >&2
    exit 1
fi

# suppress echoing user input
# credit https://stackoverflow.com/a/4316765/471376
stty_orig=$(stty -g)
trap "stty ${stty_orig}" EXIT
stty -echo

# current time in Unix epoch seconds but round down to minute
function time_now_round_minute() {
    echo -n $((($(date '+%s') / 60) * 60))
}

function print_HMS()  {
    date '+%H:%M:%S' | tr -d '\n'
}

#
# printing leading part of the first line is a special case
#

declare -i now_s=$(date '+%s')
declare -i minute_a=$(((${now_s} / 60) * 60))
declare -i seconds_in_min=$((${now_s} % 60))

# print current HMS
print_HMS
echo -n ' '
# fillup used seconds with spaces
if [[ ${seconds_in_min} -gt 0 ]]; then
    printf -- ' %.0s' $(seq 1 ${seconds_in_min})
fi

#
# printing remaining dots for the first line
# then proceed with all other lines
#

while true; do
    declare -i start_sn=$(date '+%s%N')
    # designed for BSD `iputils` ping
    if command -p ping -c1 -n -q -s248 -w1 "${@}" &> /dev/null; then
        echo -n 'ꞏ'
    else
        echo -n 'X'
    fi
    declare -i minute_b=$(time_now_round_minute)
    # print HMS at the minute rollover
    if [[ ${minute_a} -ne ${minute_b} ]]; then
        minute_a=${minute_b}
        echo -en "\n$(print_HMS) "
    fi
    # sleep the remaining amount of subsecond nanoseconds
    declare -i next_second=$(((${start_sn} / 1000000000) * 1000000000 + 1000000000))
    declare -i wait_ns=$((${next_second} - $(date '+%s%N')))
    if [[ ${wait_ns} -gt 0 ]]; then
        declare -i sleep_ns=$((${wait_ns} % 1000000000))
        sleep "0.${sleep_ns}"
    fi
done
