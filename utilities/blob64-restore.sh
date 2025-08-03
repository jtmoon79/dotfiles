#!/usr/bin/env bash
#
# decrypt $1, presuming it was stored using `blob64-store.sh`

set -euo pipefail

if [[ ${#} -lt 1  ]]; then
    bname=$(basename -- "${0}")
    echo "usage:

    ${bname} data [passphrase]

    A passphrase is read from the optional passphrase file or STDIN.

    Decrypted data is written to STDOUT.

examples:

interactive decryption:

    ${bname} /tmp/my-encrypted-data.blob64

non-interactive decryption:

    echo -n 'passw0rd' | ${bname} /tmp/my-encrypted-data.blob64

    ${bname} /tmp/my-encrypted-data.blob64 /tmp/passphrase.tmp

non-interactive decryption written to a file:

    ${bname} /tmp/my-encrypted-data.blob64 /tmp/passphrase.tmp > /tmp/my-unencrypted-data
" >&2
    exit 1
fi
input=${1}

# check validatity of optional passphrase argument before writing to the TMPFILE
if [[ ${#} -gt 1 ]]; then
    if [[ ! -e "${2}" ]]; then
        echo "ERROR Passphrase file does not exist '${2}'" >&2
        exit 1
    elif [[ ! -r "${2}" ]]; then
        echo "ERROR Passphrase file is not readable '${2}'" >&2
        exit 1
    fi
fi

TMPFILE=$(mktemp -q)
function exit_ () {
    if which shred &>/dev/null; then
        shred -z -- "${TMPFILE}"
    fi
    rm -f -- "${TMPFILE}"
}
trap exit_ EXIT

base64 -d "${input}" > "${TMPFILE}"

if [[ ${#} -gt 1 ]]; then
    gpg -o - --batch --passphrase-file "${2}" --decrypt "${TMPFILE}"
else
    # XXX: `read` returns 1 even if something was read
    read -p "Enter the passphrase " -s PASSPHRASE || true
    { echo -n "${PASSPHRASE}"; unset PASSPHRASE; } \
    | gpg -o - --batch --passphrase-fd 0 --decrypt "${TMPFILE}"
fi
