#!/usr/bin/env bash
#
# self-test of blob64 scripts

set -euo pipefail

TMPFILE_DATA1=$(mktemp --suffix .data1)
TMPFILE_DATA2=$(mktemp --suffix .data2)
TMPFILE_DATA_ENCIPHER=$(mktemp --suffix .data-enciphered)
TMPFILE_PASSPHRASE=$(mktemp --suffix .passphrase)
trap "rm -v -- ${TMPFILE_DATA1} ${TMPFILE_DATA2} ${TMPFILE_DATA_ENCIPHER} ${TMPFILE_PASSPHRASE}" EXIT

echo 'echo "HELLO!"
echo "GOODBYE!"' > "${TMPFILE_DATA1}"
PASSPHRASE='a!'
echo -n "${PASSPHRASE}" > "${TMPFILE_PASSPHRASE}"

cd "$(dirname -- "${0}")"

echo "Test with passphrase on STDIN, requires user interaction
In the following gpg dialog, the user must enter passphrase '${PASSPHRASE}'" >&2
read -p "Ready? "
echo >&2

(
    set -x
    cat "${TMPFILE_DATA1}" | ./blob64-store.sh "${TMPFILE_DATA_ENCIPHER}"
    cat "${TMPFILE_PASSPHRASE}" | ./blob64-restore.sh "${TMPFILE_DATA_ENCIPHER}" > "${TMPFILE_DATA2}"
    diff --suppress-common-lines -- "${TMPFILE_DATA1}" "${TMPFILE_DATA2}"
    cat "${TMPFILE_PASSPHRASE}" | ./blob64-run.sh "${TMPFILE_DATA_ENCIPHER}"
)

echo -n > "${TMPFILE_DATA2}"

echo '

Test with passphrase in a file
' >&2

(
    set -x
    cat "${TMPFILE_DATA1}" | ./blob64-store.sh "${TMPFILE_DATA_ENCIPHER}" "${TMPFILE_PASSPHRASE}"
    ./blob64-restore.sh "${TMPFILE_DATA_ENCIPHER}" "${TMPFILE_PASSPHRASE}" > "${TMPFILE_DATA2}"
    diff --suppress-common-lines -- "${TMPFILE_DATA1}" "${TMPFILE_DATA2}"
    ./blob64-run.sh "${TMPFILE_DATA_ENCIPHER}" "${TMPFILE_PASSPHRASE}"
)

echo "
PASSED"
