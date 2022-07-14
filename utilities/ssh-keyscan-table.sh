#!/usr/bin/env bash
#
# print SSH server fingerprint hashes in a readable table
#

set -euo pipefail
#set -x
if [[ ${#} -lt 1 ]]; then
    echo "usage:
  ${0} [keyscan options] hostname" >&2
    exit 1
fi

if ! which ssh-keyscan ssh-keygen column >/dev/null; then
    exit 1
fi

tf=$(mktemp)
trap "rm -f '${tf}'" EXIT

(ssh-keyscan -t rsa "${@}" || true) 2>&1 | head -n 1
if [[ -s "${tf}" ]]; then  # is file zero size?
    echo "ERROR bad result of ssh-keyscan" >&2
    exit 1
fi

for kt in \
          rsa \
          rsa1 \
          dsa \
          ecdsa \
          ed22519
do
    (ssh-keyscan -t "${kt}" "${@}" >> "${tf}") 2>/dev/null || true
done
(ssh-keygen -E md5 -l -f "${tf}" && ssh-keygen -l -f "${tf}") | column -t

