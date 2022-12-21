#!/usr/bin/env bash
#
# quick script to help people investigating troublesome network connections
#
# NOTE: for GNU date, %s is Unix Epoch seconds, %N is subsecond nanoseconds
#
#

set -euo pipefail

if [[ ${#} -lt 1 ]]; then
    echo -e "Usage:
    ${0} HOSTNAME [ARGS ...]

All arguments are passed to ping.

About:

A script to visually monitor a network connection over a long period of time
using ICMP ping in a per-minute visualization.

Strongly recommended to pass HOSTNAME in numeric form.

Output looks like:

    2022-12-20T21:28:00 ·························································***
    2022-12-20T21:29:00 ***·························································
    2022-12-20T21:30:00 ····························································
    2022-12-20T21:31:00 ····························································

Any user input will be used to demarcate a point in time.
For example, if the user presses key 'D' then output will look like:

    2022-12-20T21:32:00 ************************************************************
    2022-12-20T21:32:00 ***D**······················································

In the contrived example, 'D' is an arbitrary user mnemonic, say Disconnecting
some network equipment. Three seconds after that event the pings began to succeed.

Requires ping from package iputils, and GNU date.

Setting environment variable 'PING_BEAT_COLOR' to any value will colorize the
output.

Setting environment variable 'PING_BEAT_LOG' to a file path will append the
non-colorized output to that file.
" >&2
    exit 1
fi

# check that `date` supports '+%N'
# XXX: busybox `date` will accept '+%s%N' but not print the `%N` part
if ! which date &>/dev/null; then
    echo "ERROR date not in PATH" >&2
    exit 1
fi
if ! dateout=$(date '+%N' 2>&1); then
    echo "ERROR date failed:" >&2
    echo "${dateout}" >&2
    exit 1
fi
unset dateout
date1=$(date '+%N' 2>&1)
sleep 0.1
date2=$(date '+%N' 2>&1)
if [[ "${date1}" = "${date2}" ]] &>/dev/null; then
    echo "ERROR date failed to process '+%s%N'" >&2
    exit 1
fi
unset date1 date2

function ping_cmd() {
    # designed for `ping` from package `iputils`
    ping -c1 -n -q -w1 "${@}"
}

function parse_rtt_avg() {
    # $1 is output of `ping`
    # if output successfully parsed then echo the avg ms as integer (drop
    #    fractional) and return 0
    # else return 1
    #
    # reference `ping` output:
    #
    #   $ ping -c2 1.1.1.1
    #   PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
    #   64 bytes from 1.1.1.1: icmp_seq=1 ttl=53 time=22.5 ms
    #   64 bytes from 1.1.1.1: icmp_seq=2 ttl=53 time=11.9 ms
    #
    #   --- 1.1.1.1 ping statistics ---
    #   2 packets transmitted, 2 received, 0% packet loss, time 1001ms
    #   rtt min/avg/max/mdev = 11.944/17.223/22.502/5.279 ms
    #
    declare avg=
    if ! avg=$(echo -n "${1}" | tail -n 3 | grep -Ee '^rtt ' | cut -f 6 -d '/') 2>/dev/null; then
        return 1
    fi
    # $avg should be a string like "17.223"
    # drop the fractional
    avg=${avg%.*}
    if [[ -z "${avg}" ]]; then
        return 1
    fi
    # convert to integer
    declare -i avgi=${avg}
    echo -n "${avgi}"
}

# check that `ping` works as expected
# there are several varying `ping` commands among Unixii
# so good to check othewise user might think all pings are failing.
if ! out=$((set -x; ping_cmd 127.0.0.1) 2>&1); then
    echo "ERROR $(which ping) failed for 127.0.0.1; is it ping from package BSD iputils?" >&2
    echo >&2
    echo "${out}" >&2
    exit 1
fi
unset out

# suppress echoing user input, it'll mess up the line-by-line visual
# from https://stackoverflow.com/a/4316765/471376
stty_orig=$(stty -g)
trap "stty ${stty_orig}" EXIT
stty -echo

# current time in Unix epoch seconds but round down to minute
function time_now_round_minute() {
    echo -n $((($(date '+%s') / 60) * 60))
}

function print_datetime()  {
    date '+%Y-%m-%dT%H:%M:%S' | tr -d '\n'
}

#
# printing leading part of the first line; special case
#

declare -i now_s=$(date '+%s')
declare -i minute_a=$(((${now_s} / 60) * 60))
declare -i seconds_in_min=$((${now_s} % 60))
unset now_s

# prepare optional PING_BEAT_LOG
if [[ ! -z "${PING_BEAT_LOG-}" ]]; then
    if ! touch "${PING_BEAT_LOG}"}; then
        echo "ERROR failed to touch '${PING_BEAT_LOG}'" >&2
        exit 1
    fi
    if [[ -s "${PING_BEAT_LOG}" ]]; then
        echo >> "${PING_BEAT_LOG}"
    fi
    echo "${PS4}ping ${@}" >> "${PING_BEAT_LOG}"
else
    PING_BEAT_LOG=/dev/null
fi
readonly PING_BEAT_LOG

# print current HMS
echo -n "$(print_datetime) " | tee -a "${PING_BEAT_LOG}"
# fillup used seconds with spaces
if [[ ${seconds_in_min} -gt 0 ]]; then
    printf -- ' %.0s' $(seq 1 ${seconds_in_min}) | tee -a "${PING_BEAT_LOG}"
fi
unset seconds_in_min

#
# print remaining dots for the first line and all proceeding lines
# check for user input, if any then that user input will be visual demarcation
#
# one clock minute is one line of good/bad marks at approximately one per second
# XXX: not precise timing but good enough
#
# Use box-drawing to communicate RTT times.
# See https://en.wikipedia.org/wiki/Box-drawing_character
#
declare -r good='·' # '·' 'ꞏ'
declare -r good08=' ' # 0/8
declare -r good18='▁' # 1/8
declare -r good28='▂' # 2/8
declare -r good38='▃' # 3/8
declare -r good48='▄' # 4/8
declare -r good58='▅' # 5/8
declare -r good68='▆' # 6/8
declare -r good78='▇' # 7/8
declare -r good88='█' # 8/8
declare -r bad='*'  # '¤' '*' 'X'
declare -r bad99='╳'
declare -r color_good='\e[32m' # red
declare -r color_bad='\e[31m'  # green
declare -r color_norm='\e[0m'  # normalize
# set optional colorization
# using a bool is a little easier to grok instead of string check
do_color=false
if [[ ! -z "${PING_BEAT_COLOR-}" ]]; then
    do_color=true
fi
readonly do_color
user_input=
unset ping_out

while true; do
    # save the exact time before long-running `ping` command
    declare -i start_sn=$(date '+%s%N')
    # do the `ping` command, print results
    if ping_out=$(ping_cmd "${@}" 2>&1); then
        if ${do_color}; then
            echo -en "${color_good}"
        fi
        declare -i avg=0
        if [[ ! -z "${user_input}" ]]; then
            out="${user_input:0:1}"
        elif avg=$(parse_rtt_avg "${ping_out}" 2>/dev/null); then
            # `ping` waits one second for replies
            # print a visual indicator of RTT time for the scale 0 to 100
            # milliseconds
            if [[ ${avg} -le 0 ]]; then
                out="${good08}"
            elif [[ ${avg} -le 13 ]]; then
                out="${good18}"
            elif [[ ${avg} -le 25 ]]; then
                out="${good28}"
            elif [[ ${avg} -le 38 ]]; then
                out="${good38}"
            elif [[ ${avg} -le 50 ]]; then
                out="${good48}"
            elif [[ ${avg} -le 63 ]]; then
                out="${good58}"
            elif [[ ${avg} -le 75 ]]; then
                out="${good68}"
            elif [[ ${avg} -le 88 ]]; then
                out="${good78}"
            elif [[ ${avg} -le 100 ]]; then
                out="${good88}"
            else
                out="${good88}"
            fi
        else
            # the ping succeeded but parsing RTT failed
            out="${good}"
        fi
        echo -n "${out}" | tee -a "${PING_BEAT_LOG}"
        if ${do_color}; then
            echo -en "${color_norm}"
        fi
    else
        if ${do_color}; then
            echo -en "${color_bad}"
        fi
        if [[ ! -z "${user_input}" ]]; then
            out="${user_input:0:1}"
        else
            out="${bad99}"
        fi
        echo -n "${out}" | tee -a "${PING_BEAT_LOG}"
        if ${do_color}; then
            echo -en "${color_norm}"
        fi
    fi
    # print datetime only at the minute rollovers
    declare -i minute_b=$(time_now_round_minute)
    if [[ ${minute_a} -ne ${minute_b} ]]; then
        minute_a=${minute_b}
        echo -en "\n$(print_datetime) " | tee -a "${PING_BEAT_LOG}"
    fi
    # sleep the remaining amount of subsecond nanoseconds
    declare -i next_second=$(((${start_sn} / 1000000000) * 1000000000 + 1000000000))
    declare -i wait_ns=$((${next_second} - $(date '+%s%N')))
    if [[ ${wait_ns} -gt 0 ]]; then
        declare -i sleep_ns=$((${wait_ns} % 1000000000))
        sleep "0.${sleep_ns}"
    fi
    # read user input
    # XXX: read does not accept wait time value zero (`-t0`) so use a very small
    #      wait time
    user_input=
    IFS= read -s -t0.0001 -n1 user_input &>/dev/null || true
    # flush the remaining user input
    IFS= read -s -t0.0001 THROWAWAY &>/dev/null || true
done
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                