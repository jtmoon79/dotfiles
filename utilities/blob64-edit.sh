#!/usr/bin/env bash
#
# edit $1, presuming it was stored using `blob64-store.sh`, using $EDITOR

set -euo pipefail

if [[ ${#} -lt 1  ]]; then
    bname=$(basename -- "${0}")
    echo "usage:

    ${bname} file [passphrase]

    A passphrase is read from the optional passphrase file or STDIN.

    The file must be an encrypted blob64 file. Uses \$EDITOR for editing.

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
trap "rm -f -- ${TMPFILE1} ${TMPFILE2}" EXIT

BLOB=${1}

RESTORE=$(dirname -- "${0}")/blob64-restore.sh
STORE=$(dirname -- "${0}")/blob64-store.sh

(
    set -x
    "${RESTORE}" "${@}" > "${TMPFILE1}"
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
    (
        set -x
        "${STORE}" "${TMPFILE2}" < "${TMPFILE1}"
    )
fi
mv "${TMPFILE2}" "${BLOB}"
