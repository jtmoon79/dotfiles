#!/usr/bin/env bash
#
# edit $1, presuming it was stored using `blob64-store.sh`, using $EDITOR

set -euo pipefail

if [[ ${#} -lt 1  ]]; then
    bname=$(basename -- "${0}")
    echo "usage:

    ${bname} file [passphrase]

    A passphrase is read from the optional passphrase file or STDIN.

    The passed file must be an encrypted blob64 file.

    Uses \$EDITOR for editing.

about:

    ${bname} wraps the work of calling

        1. blob64-restore.sh my-encrypted-data.blob64 > my-unencrypted-data
        2. \$EDITOR my-unencrypted-data
        3. blob64-store.sh my-encrypted-data.blob64 < my-unencrypted-data
        4. rm my-unencrypted-data

    into a single command, and handles intermediary temporary files.

examples:

interactive decryption:

    ${bname} /tmp/my-encrypted-data.blob64

non-interactive decryption:

    echo -n 'passw0rd' | ${bname} /tmp/my-encrypted-data.blob64

    ${bname} /tmp/my-encrypted-data.blob64 /tmp/passphrase.tmp" >&2
    exit 1
fi

if [[ ! "${EDITOR+x}" ]]; then
    echo "ERROR \$EDITOR is not set" >&2
    exit 1
fi

TMPFILE1=$(mktemp -q)
TMPFILE2=$(mktemp -q)
TMPFILE3=$(mktemp -q)
function exit_ () {
    rm -f -- "${TMPFILE1}" "${TMPFILE2}" "${TMPFILE3}"
    # throwaway remaining STDIN
    read -t0 -s _ || true
}
trap exit_ EXIT

BLOB=${1}

RESTORE=$(dirname -- "${0}")/blob64-restore.sh
STORE=$(dirname -- "${0}")/blob64-store.sh

input=
if [[ ${#} -le 1 ]]; then
    # TODO: this should allow for using the gpg interactive dialog
    #       when the user does not pass a passphrase file on STDIN nor a passphrase file argument
    read -t0 input || true
    if [[ -z "${input}" ]]; then
        echo "ERROR passphrase passed on STDIN is empty" >&2
        echo "      did you mean to pass a passphrase file as the second argument?" >&2
        exit 1
    fi
fi

if [[ ${#} -gt 1 ]]; then
    (
        set -x
        "${RESTORE}" "${@}" > "${TMPFILE1}"
    )
else
    (
        echo -n "${input}"
    ) | (
        set -x
        "${RESTORE}" "${@}" > "${TMPFILE1}"
    )
fi
(
    set -x
    "${EDITOR}" "${TMPFILE1}"
)

if [[ ! -r "${TMPFILE1}" ]]; then
    echo "ERROR temporary file for editing ${TMPFILE1} was lost; EDITOR '${EDITOR}'" >&2
    exit 1
fi

if [[ ${#} -gt 1 ]]; then
    (
        set -x
        "${STORE}" "${TMPFILE2}" "${2}" < "${TMPFILE1}"
    )
else
    # user passed password via STDIN, temporarily store it in a file
    # this way the user doesn't have to type it the gpg dialog
    # XXX: how to obscure this from list of process command lines?
    echo -n "${input}" > "${TMPFILE3}"
    (
        set -x
        "${STORE}" "${TMPFILE2}" "${TMPFILE3}" < "${TMPFILE1}"
    )
    # remove the password as soon as possible
    rm -f -- "${TMPFILE3}"
fi

mv "${TMPFILE2}" "${BLOB}"
