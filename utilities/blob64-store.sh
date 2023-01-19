#!/usr/bin/env bash
#
# encrypt STDIN, transform to base64, write to $1
#

set -euo pipefail

if [[ ${#} -lt 1 ]]; then
    bname=$(basename -- "${0}")
    echo "\
usage:

    ${bname} output [passphrase]

    Data is read from STDIN. enciphered data is written to path output.

    An optional second argument is a path to a file with a passphrase.
    If a passphrase file is not passed then gpg will create an interactive
    dialog for the user to enter the passphrase.

about:

    encrypt data using gpg symmetric cipher then base64 the data.
    Later, use blob64-decrypt.sh to decrypt.

examples:

    echo 'SECRET DATA!' | ${bname} /tmp/my-encrypted-secrets.blob64

    echo 'echo hello && touch /tmp/test' | ${bname} /tmp/my-encrypted-script.blob64

    echo 'passw0rd' > /tmp/password
    echo 'echo hello && touch /tmp/test' | ${bname} /tmp/my-encrypted-script.blob64 /tmp/password

Later, the file my-encrypted-script.blob64 can be run in a bash shell using

    echo -n 'passw0rd' | blob64-run.sh /tmp/my-encrypted-script.blob64" >&2
    exit 1
fi

output=${1}

# use temporary file in case user cancels operation, the file is not modified
TMPFILE=$(mktemp -q)
function exit_ () {
    if which shred &>/dev/null; then
        shred -z -- "${TMPFILE}"
    fi
    rm -f -- "${TMPFILE}"
}
trap exit_ EXIT

declare -a gpg_extra_args=()

# set gpg arguments based on passphrase setting
if [[ ${#} -gt 1 ]]; then
    if [[ ! -e "${2}" ]]; then
        echo "ERROR Passphrase file does not exist '${2}'" >&2
        exit 1
    elif [[ ! -r "${2}" ]]; then
        echo "ERROR Passphrase file is not readable '${2}'" >&2
        exit 1
    fi
    gpg_extra_args[0]='--batch'
    gpg_extra_args[1]='--passphrase-file'
    gpg_extra_args[2]=${2}
fi

gpg "${gpg_extra_args[@]}" --yes --no-symkey-cache --symmetric - \
    | base64 > "${TMPFILE}"

mv -- "${TMPFILE}" "${output}"
