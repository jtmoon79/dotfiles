#!/usr/bin/env bash
#
# decrypt $1, which should be a file encrypted by script
# `blob64-store.sh`, run that decrypted script file in bash
#
# useful for running scripts that need to embed secrets
#

set -euo pipefail

if [[ ${#} -lt 1 ]]; then
    bname=$(basename -- "${0}")
    echo "usage:

    ${bname} script [passphrase]

    The script is a bash shell compatible file to run, that has been encrypted
    using blob64-store.sh.

    A passphrase is read from the optional passphrase file or STDIN.

examples:

    echo -n 'passw0rd' | ${bname} /tmp/my-encrypted-script.gpg.base64

    ${bname} /tmp/my-encrypted-script.gpg.base64 /tmp/my-passphrase" >&2
    exit 1
fi

input=${1}
restore_script=$(dirname -- "${0}")/blob64-restore.sh

if [[ ! -f "${restore_script}" ]]; then
    echo "ERROR partner script not found '${restore_script}'" >&2
    exit 1
elif [[ ! -x "${restore_script}" ]]; then
    echo "ERROR partner script not executable '${restore_script}'" >&2
    exit 1
fi

if [[ ${#} -ge 2 ]]; then
    "${restore_script}" "${input}" "${2}" | bash --norc --noprofile
else
    "${restore_script}" "${input}" | bash --norc --noprofile
fi
