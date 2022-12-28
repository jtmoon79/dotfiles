#!/usr/bin/env bash

set -euo pipefail

function generate_char_latin() {
    # generate a more portable low-value unicode character from ASCII to Latin
    # Extended-B
    # Using unicode characters U+0 (0) to U+024F (591)
    # see https://en.wikipedia.org/wiki/List_of_Unicode_characters#Latin_script
    declare -i CHARN=0
    while CHARN=$((${RANDOM} % 0x024F)); do
        if [[ ${CHARN} -gt 31 ]] \
        && [[ ${CHARN} -ne 127 ]] \
        && [[ ${CHARN} -ne 141 ]] \
        && [[ ${CHARN} -ne 143 ]] \
        && [[ ${CHARN} -ne 144 ]] \
        && [[ ${CHARN} -ne 157 ]]
        then
            break
        fi
    done
    printf "\U$(printf '%02X' ${CHARN})"
}

function generate_char_chinese() {
    # generate a Chinese character from CJK Compatibility Ideographs
    # Using unicode characters U+F900 (63744) to U+FA6C (64108), difference 364
    # see https://en.wikipedia.org/wiki/CJK_Compatibility_Ideographs
    declare -i CHARN=0
    CHARN=$(((${RANDOM} % 364) + 0xF900))
    printf "\U$(printf '%04X' ${CHARN})"
}

function generate_char_japanese() {
    # generate a movie-accurate Japanese ideographs
    # https://www.cnet.com/culture/entertainment/lego-ninjago-movie-simon-whiteley-matrix-code-creator/
    # Using unicode characters U+3041 to U+3096, difference 0x55 (85) (Kanji)
    #                          U+2E80 to U+2FD5, difference 0x155 (341) (Kanji Radicals)
    # see https://stackoverflow.com/a/53807563/471376
    declare -i CHARN=0
    CHARN=$((${RANDOM} % (0x55 + 0x155)))
    if [[ ${CHARN} -gt 0x55 ]]; then
        CHARN=$((CHARN + 0x3041))
    else
        CHARN=$((CHARN + 0x2E80))
    fi
    printf "\U$(printf '%04X' ${CHARN})"
}

alpha='japanese'
if [[ ${#} -gt 0 ]]; then
    if [[ "${1-}" == '--ASCII' || "${1-}" == '--ascii' || "${1-}" == '--latin' ]]; then
        alpha='latin'
    elif [[ "${1-}" == '--china' || "${1-}" == '--chinese' || "${1-}" == '--han' ]]; then
        alpha='chinese'
    else
        echo "usage:
    $(basename "${0}") [--latin|--chinese]

Defaults to movie-accurate Japanese characters." >&2
        exit 1
    fi
fi

while true; do
    LINES=$(tput lines)
    COLUMNS=$(tput cols)
    # pick a random character value but disclude control and format characters
    # see https://www.ascii-code.com/
    if [[ "${alpha}" = 'chinese' ]]; then
        CHAR=$(generate_char_chinese)
    elif [[ "${alpha}" = 'latin' ]]; then
        CHAR=$(generate_char_latin)
    else
        CHAR=$(generate_char_japanese)
    fi
    echo ${LINES} ${COLUMNS} $((${RANDOM} % ${COLUMNS})) "${CHAR}"
    sleep 0.05
    # awk code modified from https://twitter.com/climagic/status/1472931718214651912
done | gawk '
{
    a[$3]=0;
    for (x in a) {
        o=a[x];
        a[x]=a[x]+1;
        printf "\033[%s;%sH\033[2;32m%s", o, x, $4;
        printf "\033[%s;%sH\033[1;37m%s\033[0;0H", a[x], x, $4;
        if (a[x] >= $1) {
            a[x]=0;
        }
    }
}'
