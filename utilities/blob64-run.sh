#!/usr/bin/env bash
#
# decrypt $1, which should be a file encrypted by script
# `blob64-store.sh`, run that decrypted script file in bash
#
# useful for running scripts that need to embed secrets
#

set -euo pipefail

if [[ ${#} -ne 1 ]]; then
    echo "usage:

    gpg_passphrase | ${0} script

Passphrase is read from STDIN

example:

    echo -n 'passw0rd' | ${0} /tmp/my-encrypted-script.gpg.base64" >&2
    exit 1
fi

input=${1}
restore_script=$(dirname -- "${0}")/blob64-restore.sh

if [[ ! -f "${restore_script}" ]]; then
    echo "ERROR file not found '${restore_script}'" >&2
    exit 1
elif [[ ! -x "${restore_script}" ]]; then
    echo "ERROR file not executable '${restore_script}'" >&2
    exit 1
fi

set -x
exec "${restore_script}" "${input}" | bash --norc --noprofile
