#!/usr/bin/env bash
#
# encrypt STDIN, transform to base64, write to $1
#

set -euo pipefail

if [[ ${#} -ne 1 ]]; then
    echo "usage:

    ${0} file

Data is read from STDIN.

examples:

    echo 'S3CR3TS!!!' | ${0} /tmp/my-encrypted-secrets.gpg.base64

    echo 'echo hello && touch /tmp/test' | ${0} /tmp/my-encrypted-script.gpg.base64

Later, the file my-encrypted-script.gpg.base64 can be run in a bash shell using

    echo -n 'passw0rd' | blob64-run.sh /tmp/my-encrypted-script.gpg.base64" >&2
    exit 1
fi

output=${1}

(
set -x
gpg -v --yes --symmetric --no-symkey-cache - \
    | base64 > "${output}"
)
ls -la "${output}" >&2
