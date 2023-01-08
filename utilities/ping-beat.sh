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

A script to visually monitor a network connection over a long duration of time
in a per-minute visualization. It uses ICMP to deteremine if a host is
online.

It is strongly recommended to pass HOSTNAME in numeric address form.

Output looks like:

    2022-12-20T15:45:00 ▃▃▃▃▃▃▃▃▄▃▃▃▅▃▃▃▃▃▃▃▃▃▃▅▃▃▃▃▃▃█▃▃█▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▇▃▃▃▃▃▃▃╳╳
    2022-12-20T15:46:00 ╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳

(hopefully the characters are aligned)

Any user input will be used to demarcate a point in time.
For example, if the user presses key 'D' then output will look like:

    2022-12-20T15:46:00 ╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳╳D╳╳╳╳▃▄▃▃▃▃▃


In the contrived example, 'D' is an arbitrary user mnemonic, say Disconnecting
some network equipment. Three seconds after that event the pings began to
succeed.

Setting environment variable 'PING_BEAT_NOCOLOR' to any value will turn off
color escape sequences.

Setting environment variable 'PING_BEAT_TIMEONLY' to any value will print
only the Hour, Minute, and Second.

Setting environment variable 'PING_BEAT_LOG' to a file path will append the
non-colorized output to that file.

Setting environment variable 'PING_BEAT_ASCII' to any value will print only
ASCII characters.
This is useful for visual alignment problems that may occur with some font
and terminal combinations.

Setting environment variable 'PING_BEAT_CONNECT_TCP' to any value will use
netcat to create a TCP connection to port. Port is the second script argument.

Requires programs ping from package iputils or busybox, and date from GNU
coreutils.

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
sleep 0.01
date2=$(date '+%N' 2>&1)
if [[ "${date1}" = "${date2}" ]] &>/dev/null; then
    echo "ERROR date failed to process '+%s%N'" >&2
    exit 1
fi
unset date1 date2

function ping_cmd() {
    if ! ${do_netcat}; then
        # designed for `ping` from package `iputils` or busybox
        ping -c1 -n -q -w1 "${@}"
    else
        # tested against BSD `nc` from package
        nc -N -d -w 1 "${@}"
    fi
}

function parse_rtt_avg() {
    # $1 is output of `ping`
    # if output successfully parsed then echo the avg ms as integer (drop
    #    fractional) and return 0
    # else return 1
    #
    # reference output from `iputils` ping:
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
    # TODO: what does ping time greater than 1 second look like?
    #       do milliseconds become just seconds?
    #
    # reference output from busybox ping:
    #
    #     $ ping -c1 -n -q -w1 127.0.0.1
    #     PING 127.0.0.1 (127.0.0.1): 56 data bytes
    #
    #     --- 127.0.0.1 ping statistics ---
    #     1 packets transmitted, 1 packets received, 0% packet loss
    #     round-trip min/avg/max = 0.121/0.121/0.121 ms
    #
    declare avg=
    if avg=$(echo -n "${1}" | tail -n 3 | grep -Ee '^rtt ' | cut -f 6 -d '/') 2>/dev/null; then
        true
    elif avg=$(echo -n "${1}" | tail -n 3 | grep -Ee '^round-trip ' | cut -f 4 -d '/') 2>/dev/null; then
        true
    else
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


# optional environment flag
do_netcat=false
if [[ ! -z "${PING_BEAT_CONNECT_TCP-}" ]]; then
    do_netcat=true
fi
readonly do_netcat

# check that `ping` works as expected
# there are several varying `ping` commands among Unixii
# so make sure this one is acceptable othewise user might think all pings are
# failing.
if ! ${do_netcat} && ! out=$((set -x; ping_cmd 127.0.0.1) 2>&1); then
    echo "ERROR $(which ping) failed for 127.0.0.1; is it ping from package iputils or busybox?" >&2
    echo >&2
    echo "${out}" >&2
    exit 1
fi
unset out

# suppress echoing user input, restore tty settings upon exit
# from https://stackoverflow.com/a/4316765/471376
stty_conf=$(stty -g)
trap "stty ${stty_conf}" EXIT
stty -echo
readonly stty_conf

# number of sub-second fractional nanoseconds, e.g. nanoseconds in one second
declare -ir n_in_s=1000000000
# number of sub-minute fractional nanoseconds, e.g. nanoseconds in one minute
declare -ir n_in_m=$((n_in_s * 60))

# current time in Unix epoch seconds but round down to minute
function datetime_now_round_minute() {
    echo -n $((($(date '+%s') / 60) * 60))
}

# current datetime in seconds&nanoseconds
function datetime_now_sn() {
    date '+%s%N'
}

declare -i now_s=$(date '+%s')
declare -i now_minute_a_s=$(((${now_s} / 60) * 60))
declare -i seconds_into_min=$((${now_s} % 60))
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
    echo "${PS4}$(basename -- "${0}") ${@}" >> "${PING_BEAT_LOG}"
else
    PING_BEAT_LOG=/dev/null
fi
readonly PING_BEAT_LOG

# optional environment flag
do_only_ascii=false
if [[ ! -z "${PING_BEAT_ASCII-}" ]]; then
    do_only_ascii=true
fi
readonly do_only_ascii

# optional enviroment flag
do_datetime_timeonly=false
if [[ ! -z "${PING_BEAT_TIMEONLY-}" ]]; then
    do_datetime_timeonly=true
fi
readonly do_datetime_timeonly

function print_datetime()  {
    declare format="+%Y-%m-%dT%H:%M:${1-%S}"
    if ${do_datetime_timeonly}; then
        format="+%H:%M:${1-%S}"
    fi
    date "${format}" | tr -d '\n'
}

#
# first script printing
#

# print current HMS
echo -n "$(print_datetime) " | tee -a "${PING_BEAT_LOG}"
# fillup used seconds with spaces
declare -i minute_dot_at=0
if [[ ${seconds_into_min} -gt 0 ]]; then
    printf -- ' %.0s' $(seq 1 ${seconds_into_min}) | tee -a "${PING_BEAT_LOG}"
    minute_dot_at=${seconds_into_min}
fi
unset seconds_into_min

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

# ping result dots
declare -r dot_good_ASCII='·' # ASCII Extended
declare -r dot_good='·' # fallback
declare -r dot_good08=' ' # 0/8
declare -r dot_good18='▁' # 1/8
declare -r dot_good28='▂' # 2/8
declare -r dot_good38='▃' # 3/8
declare -r dot_good48='▄' # 4/8
declare -r dot_good58='▅' # 5/8
declare -r dot_good68='▆' # 6/8
declare -r dot_good78='▇' # 7/8
declare -r dot_good88='█' # 8/8
declare -r dot_good99='░' # >8/8
declare -r dot_bad_ASCII='*' # ASCII
declare -r dot_bad99='╳'
declare -r dot_skip=' '
declare -r dot_skip_ASCII=' '
# ping result colors
declare -r color_good='\e[32m' # red
declare -r color_bad='\e[31m'  # green
declare -r color_norm='\e[0m'  # normalize
# set optional colorization
# using a bool is a little easier to grok instead of string check
do_color=true
if [[ ! -z "${PING_BEAT_NOCOLOR-}" ]]; then
    do_color=false
fi
readonly do_color

user_input=
unset ping_out

while true; do
    # save the exact time before long-running `ping` command
    declare -i start_sn=$(datetime_now_sn)  # loop start datetime in seconds&nanoseconds
    # do the `ping` command, print results based on various flags and inputs
    if ping_out=$(ping_cmd "${@}" 2>&1); then
        if ${do_color}; then
            echo -en "${color_good}"
        fi
        declare -i avg=0
        if [[ ! -z "${user_input}" ]]; then
            dot="${user_input:0:1}"
        elif ${do_only_ascii}; then
            dot="${dot_good_ASCII}"
        elif avg=$(parse_rtt_avg "${ping_out}" 2>/dev/null); then
            # `ping` waits one second for replies
            # print a visual indicator of RTT time for the scale 0 to 100
            # milliseconds
            if [[ ${avg} -le 0 ]]; then
                dot="${dot_good08}"
            elif [[ ${avg} -le 130 ]]; then
                dot="${dot_good18}"
            elif [[ ${avg} -le 250 ]]; then
                dot="${dot_good28}"
            elif [[ ${avg} -le 380 ]]; then
                dot="${dot_good38}"
            elif [[ ${avg} -le 500 ]]; then
                dot="${dot_good48}"
            elif [[ ${avg} -le 630 ]]; then
                dot="${dot_good58}"
            elif [[ ${avg} -le 750 ]]; then
                dot="${dot_good68}"
            elif [[ ${avg} -le 880 ]]; then
                dot="${dot_good78}"
            elif [[ ${avg} -le 1000 ]]; then
                dot="${dot_good88}"
            else
                # this shouldn't happen; ping timeout is 1 second and
                # `ping` prints in milliseconds
                dot="${dot_good99}"
            fi
        else
            # the ping succeeded but parsing RTT failed
            dot="${dot_good}"
        fi
        echo -n "${dot}" | tee -a "${PING_BEAT_LOG}"
        if ${do_color}; then
            echo -en "${color_norm}"
        fi
    else
        if ${do_color}; then
            echo -en "${color_bad}"
        fi
        if [[ ! -z "${user_input}" ]]; then
            dot="${user_input:0:1}"
        elif ${do_only_ascii}; then
            dot="${dot_bad_ASCII}"
        else
            dot="${dot_bad99}"
        fi
        echo -n "${dot}" | tee -a "${PING_BEAT_LOG}"
        if ${do_color}; then
            echo -en "${color_norm}"
        fi
    fi
    #
    # print extra information only at the minute rollovers
    # at end of row print ping info
    # at beginning of new row print datetime
    #
    # current datetime in seconds&nanoseconds
    declare -i now_sn=$(datetime_now_sn)
    # current datetime in seconds&nanoseconds truncated minute
    declare -i now_minute_sn=$(((now_sn / n_in_m) * n_in_m))
    # next minute datetime in seconds&nanoseconds truncated minute
    declare -i now_minute_b_sn=$(($now_minute_sn + n_in_m))
    # current datetime in seconds truncated minute
    declare -i now_minute_b_s=$((((now_sn / n_in_s) / 60) * 60))
    if [[ ${now_minute_a_s} -ne ${now_minute_b_s} ]]; then
        # reached the minute rollover datetime
        while [[ ${minute_dot_at} -lt 59 ]]; do
            # reached the end of the minute time, but there are still dots that
            # have not been printed. So quickly print remaining "skip" dots.
            # This should result in 60 dots printed per row.
            if ${do_only_ascii}; then
                dot="${dot_skip_ASCII}"
            else
                dot="${dot_skip}"
            fi
            echo -n "${dot}" | tee -a "${PING_BEAT_LOG}"
            minute_dot_at+=1
        done
        now_minute_a_s=${now_minute_b_s}
        # print ping information at end of current row
        echo " (${@})" | tee -a "${PING_BEAT_LOG}"
        # print datetime information at start of a new row
        echo -en "$(print_datetime 00) " | tee -a "${PING_BEAT_LOG}"
        minute_dot_at=0
        declare -i remain_s=60
    else
        minute_dot_at+=1
        # remaining nanoseconds in current minute
        declare -i remain_ns=$((n_in_m - (now_sn % now_minute_sn)))
        if [[ ${remain_ns} -lt 0 ]]; then
            remain_ns=0
        fi
        # remaining seconds in cur_minute
        declare -i remain_s=$((remain_ns / n_in_s))
    fi
    #
    # sleep up for duration that this should be at for the row minute
    #
    declare -i minute_dot_expect=$((60 - remain_s))
    # wait duration in nanoseconds (not a sub-second fractional)
    declare -i wait_n=0
    if [[ ${minute_dot_expect} -le ${minute_dot_at} ]]; then
        # getting ahead of things or nearly on-track (within .1 second)
        #
        # add sub-second nanoseconds to wait minus .1 second
        # (allow starting the next loop iteration a little bit early)
        wait_n=$(((minute_dot_at - minute_dot_expect) * n_in_s - 100000000))
        # add seconds to wait but as nanoseconds
        wait_n+=$((now_sn % n_in_s))
        if [[ ${wait_n} -gt 0 ]]; then
            declare -i sleep_n=$((${wait_n} % n_in_s))
            declare sleep_n_str=$(printf '%09d' ${sleep_n})
            declare -i sleep_s=$((${wait_n} / n_in_s))
            sleep "${sleep_s}.${sleep_n}"
        fi
        #minute_dot_at+=1
    else
        # falling behind too far behind,
        # skip the next ping(s), print skip dot for this "second column"
        declare -i skip_ahead=$((${minute_dot_expect} - ${minute_dot_at}))
        while [[ ${skip_ahead} -gt 0 ]]; do
            if ${do_only_ascii}; then
                dot="${dot_skip_ASCII}"
            else
                dot="${dot_skip}"
            fi
            echo -n "${dot}" | tee -a "${PING_BEAT_LOG}"
            minute_dot_at+=1
            skip_ahead=$((skip_ahead - 1))
        done
    fi
    #
    # read user input for optional overwrite
    #
    # XXX: read does not accept wait time value zero (`-t0`) so use a very small
    #      wait time
    user_input=
    IFS= read -s -t0.0001 -n1 user_input &>/dev/null || true
    # flush the remaining user input so accidental keysmash does not print
    # a bunch of non-sense over a long duration
    #IFS= read -s -t0.0001 THROWAWAY &>/dev/null || true
done
                                