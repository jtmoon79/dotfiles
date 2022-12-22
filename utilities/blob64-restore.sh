#!/usr/bin/env bash
#
# decrypt $1, presuming it was stored using `blob64-store.sh`

set -euo pipefail

if [[ ${#} -ne 1 ]]; then
    echo "usage:

    ${0} file

Passphrase is read from STDIN and can be interactive.
Decrypted data is written to STDOUT.

example:

interactive decryption:

    ${0} /tmp/my-encrypted-data.gpg.base64

non-interactive decryption:

    echo -n 'passw0rd' | ${0} /tmp/my-encrypted-data.gpg.base64" >&2
    exit 1
fi
input=${1}

TMPFILE=$(mktemp -q)
trap "rm -f -- ${TMPFILE}" EXIT

# XXX: `read` returns 1 even if something was read
read -p "Enter the passphrase " -s PASSPHRASE || true

(set -x; base64 -d "${input}") > "${TMPFILE}"
{ echo -n "${PASSPHRASE}"; unset PASSPHRASE; } \
| (set -x; gpg -v -o - --batch --passphrase-fd 0 --decrypt "${TMPFILE}")
