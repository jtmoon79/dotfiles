#!/usr/bin/env bash
#
# quick+basic encrypted backup of a file (useful for encrypted disk images)

set -euo pipefail

if [[ ${#} -lt 1 ]] || [[ "${1:-}" == '--help' ]]; then
    bname=$(basename -- "${0}")
    echo "usage:
    ${bname} SOURCE [TARGET [NAME]]

dd the SOURCE file to 7zip compression and encryption to directory TARGET
using file name NAME.

The optional variables may be overridden, i.e.

    SOURCE=/dev/sdb TARGET=/mnt/backups NAME=mybackup.img ${bname}

Most useful for quick ad-hoc image backups of small Linux character devices
(e.g. whole disks).
Could be used to backup+encrypt any other single path.
" >&2
    exit 1
fi

for prog in dd 7z pv sha256sum; do
    if ! which "${prog}" &>/dev/null; then
      echo "Cannot find program '${prog}'" >&2
      exit 1
    fi
done

# backup this source/device
SOURCE_PATH=${SOURCE-${1}}
# backup to this target file
BACKUP_PATH=${TARGET-${2}}
NAME_OS=$(source /etc/os-release || exit 0; echo -n "${ID-}_${VERSION_ID-}_${VERSION_CODENAME-}-")
BACKUP_NAME_IMG=${NAME-${3-"$(hostname)-${NAME_OS}$(date '+%Y%m%dT%H%M%S')-[${SOURCE_PATH//\//_}].img"}}
BACKUP_NAME_IMG_7Z=${BACKUP_NAME_IMG}.7z
BACKUP_NAME_IMG_7Z_SUM=${BACKUP_NAME_IMG_7Z}.sha256
BACKUP_PATH_IMG=${BACKUP_PATH}/${BACKUP_NAME_IMG}
BACKUP_PATH_IMG_7Z=${BACKUP_PATH}/${BACKUP_NAME_IMG_7Z}
BACKUP_PATH_IMG_7Z_SUM=${BACKUP_PATH}/${BACKUP_NAME_IMG_7Z_SUM}
BACKUP_PATH_IMG_7Z_INFO=${BACKUP_PATH}/${BACKUP_NAME_IMG_7Z}.info

# test the target directory can be written
if ! (touch "${BACKUP_PATH_IMG_7Z}" && rm -f "${BACKUP_PATH_IMG_7Z}"); then
    echo "ERROR could not write to the path '${BACKUP_PATH_IMG_7Z}'" >&2
    exit 1
fi

function err_exit () {
    rm -fv -- \
        "${BACKUP_PATH_IMG_7Z}" \
        "${BACKUP_PATH_IMG_7Z_SUM}" \
        "${BACKUP_PATH_IMG_7Z_INFO}"
}
trap err_exit EXIT

dd --version | head -n1
echo

# archive and encrypt
#
# XXX: Allow the password to be echoed in the terminal by `read`.
#      The user can double-check it.
#      A little unsafe, but better than entering the wrong password.
(
    read -p "enter 7z password:" password

    set -x
    # the important command of this script
    dd status=none if="${SOURCE_PATH}" | pv --rate --eta --bytes --timer | 7z a -bd -stl "-p${password}" -si "${BACKUP_PATH_IMG_7Z}"

    # test the archive
    7z t "-p${password}" "${BACKUP_PATH_IMG_7Z}"
)

(
    BACKUP_PATH_IMG_7Z_SUM=$(realpath -- "${BACKUP_PATH_IMG_7Z_SUM}")
    cd "${BACKUP_PATH}"
    set -x
    # in addition to 7z CRC, create a checksum file
    sha256sum --binary "${BACKUP_NAME_IMG_7Z}" > "${BACKUP_PATH_IMG_7Z_SUM}"
)

# leave a note to help those trying to figure out what the backup file is all about
(
    BS_RP=$(realpath "${SOURCE_PATH}")
    if [[ "${BS_RP}" != "${SOURCE_PATH}" ]]; then
        BS_RP_MESG=" ('${BS_RP}')"
    else
        BS_RP_MESG=''
    fi
    AT_RP=$(realpath "${BACKUP_PATH_IMG_7Z}")
    if [[ "${AT_RP}" != "${BACKUP_PATH_IMG_7Z}" ]]; then
        AT_RP_MESG=" ('${AT_RP}')"
    else
        AT_RP_MESG=''
    fi

    echo "\
Backup Source was:

    '${SOURCE_PATH}'${BS_RP_MESG}
    $(ls -1lhd "${SOURCE_PATH}")

Archive Target was:

    '${BACKUP_NAME_IMG_7Z}'${AT_RP_MESG}
    $(ls -1lhd "${BACKUP_PATH_IMG_7Z}")

Checksum file '${BACKUP_NAME_IMG_7Z_SUM}'

Checksum:

    $(cat "${BACKUP_PATH_IMG_7Z_SUM}" | tr -d '\n')

Archive+encrypt command was:

    dd if='${SOURCE_PATH}' | 7z a -stl -si '${BACKUP_NAME_IMG_7Z}'

Decrypt to a file:

    7z x -so -p*** '${BACKUP_NAME_IMG_7Z}' > '${BACKUP_NAME_IMG}'

Decrypt to directly to the device/source (restore):

    7z x -so -p*** '${BACKUP_NAME_IMG_7Z}' | dd of='${SOURCE_PATH}'

SHA256 Checksum command is:

    sha256sum --check '${BACKUP_NAME_IMG_7Z_SUM}'

Archive data:

$(7z l -slt "${BACKUP_PATH_IMG_7Z}" 2>&1 | sed 's/^/    /g')
"
) &> "${BACKUP_PATH_IMG_7Z_INFO}"
echo
echo

# draw a horizontal line
for i in $(seq 1 ${COLUMNS}); do echo -n '-'; done;

cat "${BACKUP_PATH_IMG_7Z_INFO}"

trap '' EXIT
