#!/usr/bin/env bash
#
# Print SSH server fingerprint hashes in a readable table
#

set -euo pipefail

if [[ ${#} -lt 1 ]]; then
    bname=$(basename "${0}")
    echo "Print SSH server fingerprint hashes in a readable table.

usage:

    ${bname} [keyscan options] hostname

example:

    \$ ${bname} 192.168.1.1
    # 192.168.1.1:22 SSH-2.0-OpenSSH_8.5p1 Debian-5+deb11u1
    3072  MD5:4f:ff:ee:78:52:dd:aa:c2:38:8b:15:8a:17:86:25:31  192.168.1.1  (RSA)
    256   MD5:e7:3a:22:43:f0:15:e1:ff:e0:38:2f:00:26:a5:78:eb  192.168.1.1  (ECDSA)
    3072  SHA256:B03Que3y433ty7kVsGgFrmau62/3/Zl7PeqlzZTYsvs   192.168.1.1  (RSA)
    256   SHA256:ujuU+TW+yRRlcwzQ3TEzeRdSifd6w674PosThQGHDU8   192.168.1.1  (ECDSA)" >&2
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
