#!/usr/bin/env bash
#
# script to tail all logs
# helpful for keeping an eye on things
#
# if `multitail` is available then use it else use `tail`

set -eu

# print all logs for passed paths, default to `/var/log/`
function find_logs() {
    find "${@-/var/log/}" \
        \( -type f -o -type l \) \
        \( -name '*log' -or -name 'log*' -or -name '*err' -or -name '*.error' -or -name 'messages' -or -name 'dmesg' \) \
        -not \( -name '*.xz' -or -name '*.gz' \) \
        -print \
    | sort \
    | uniq
}

if ! which multitail &> /dev/null; then
    set -x
    exec -- \
        tail -f -- \
            $(find_logs "${@}")
fi

# build up the multitail command line arguments

declare -a logs=()
while read log; do
    logs[${#logs[@]}]=${log}
done <<< $(find_logs "${@}")

declare -a arg_logs=()
for log in "${logs[@]}"; do
    # so the arguments addtions looks like
    #    --label 'some.log: ' /var/log/some.log
    arg_logs[${#arg_logs[@]}]='--label'
    arg_logs[${#arg_logs[@]}]="$(basename -- "${log}")｜	"
    arg_logs[${#arg_logs[@]}]=${log}
done

set -x
exec -- \
    multitail \
    --mergeall \
    "${arg_logs[@]}"
