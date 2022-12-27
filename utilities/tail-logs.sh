#!/usr/bin/env bash
#
# script to tail all logs
# helpful for keeping an eye on all the logs of a system
#
# if `multitail` is available then use it else use `tail`

set -eu

# print all log file paths for passed paths
function find_logs() {
    find \
        -L \
        "${@}" \
        -type f \
        \( -name '*log' -or -name 'log*' -or -name '*err' -or -name '*.error' -or -name 'messages' -or -name 'dmesg' \) \
        -not \( -name '*.xz' -or -name '*.gz' -or -name '*.tar' -or -name '*.tgz' -or -name '*.zip' -or -name '*.journal' \) \
        -print \
    | sort \
    | uniq
}

if ! which multitail &> /dev/null; then
    set -x
    exec -- \
        tail -f -- \
            $(find_logs "${@-/var/log/}")
fi

# gather all log file paths into an array
declare -a logs=()
while read log; do
    logs[${#logs[@]}]=${log}
done <<< $(find_logs "${@-/var/log/}")

# repeat the passed string $1 for $2 times
function repeat() {
    declare -i num="${2-10}"
    if [[ ${num} -lt 1 ]]; then
        return
    fi
    printf -- "${1}%.0s" $(seq 1 ${num})
}

function strlen() {
    expr length "${1}"
}

# get the length of the longest file basename
declare -i name_longest=0
for log in "${logs[@]}"; do
    declare -i len=$(strlen "$(basename -- "${log}")")
    if [[ ${name_longest} -lt ${len} ]]; then
        name_longest=${len}
    fi
done

# build-up the `multitail` arguments, add a special `--label` for
# each log file that will be tailed
declare -a arg_logs=()
for log in "${logs[@]}"; do
    # so the arguments addtions looks like
    #    --label 'some.log: ' /var/log/some.log
    arg_logs[${#arg_logs[@]}]='--label'
    # add extra space padding to label so the visual column is aligned
    declare -i len=$(strlen "$(basename -- "${log}")")
    declare extra=$(repeat ' ' $((name_longest - len)))
    # XXX: label does not interpret shell escape codes
    #      so cannot, for example, underline the label value
    arg_logs[${#arg_logs[@]}]="$(basename -- "${log}")${extra}｜ "
    arg_logs[${#arg_logs[@]}]=${log}
done

set -x
exec -- \
    multitail \
    --mergeall \
    "${arg_logs[@]}"
