#!/usr/bin/env bash
#
# quick imperfect script to tar a path and 7zip encrypt the tar
# useful for quick encrypted backups

set -e
set -u
set -o pipefail

BACKUP_DIR=${BACKUP_DIR-'/root/backups'}

function backup_name_tar() {
    echo -n "${BACKUP_DIR}/$(hostname)__${1}__$(date +%Y%m%d).tar"
}

if [[ ${#} != 1 && ${#} != 2 ]] || [[ "${1:-}" == '--help' ]]; then
    name="$(backup_name_tar '$1').7z"
    echo "usage:
    ${0} /path/to/backup [/backup/destination/dir]

Tar and 7zip a target path.
Tar to preserve filesystem permissions and layout. 7zip to compress and encrypt.
REQUIRES ENTERING A PASSWORD.

Backup to an archive file based on the host and path passed,
e.g. '${name}'

Decrypt the archive file with command:

    7z e '${name}' -so | tar --verbose -xf - -C /some/path

REQUIRES ENTERING A PASSWORD.
" >&2
    exit 1
fi

target=${1}
if [[ ! -e "${target}" ]]; then
    echo "ERROR: Target '${target}' does not exist" >&2
    exit 1
fi
BACKUP_DIR=${2:-${BACKUP_DIR}}
readonly BACKUP_DIR target

name=$(basename -- "$(readlink -f -- "${target}")")
archive_tar=$(backup_name_tar "${name}")
archive_tar7z="${archive_tar}.7z"
readonly name archive_tar archive_tar7z

read -p "Enter the 7z archive password: " -s password
#password_file=$(mktemp)
#echo -n "${password}" > "${password_file}"
#function exit_() {
#    rm -f "${password_file}" &>/dev/null || true
#}
#trap exit_ EXIT

(
set -x

function exit_() {
    rm -vf -- "${archive_tar}"
}
trap exit_ EXIT

tar \
  --create \
  --preserve-permissions \
  --sort=name \
  --one-file-system \
  --ignore-failed-read \
  --file="${archive_tar}" \
  --directory="${target}" \
  .

tar \
  -t \
  -f "${archive_tar}" >/dev/null

# stupidly, echoes the password :-(
7z a \
  -p"${password}" \
  -t7z \
  -m0=lzma2 \
  -mx=9 \
  -mfb=64 \
  -md=32m \
  -ms=on \
  -mhe=on \
   "${archive_tar7z}" "${archive_tar}" \

# echoes the password :-(
7z l \
   -p"${password}" \
   -slt \
   "${archive_tar7z}"
)

echo "Success! Restore this archive with

    7z e '${archive_tar7z}' -so | tar --verbose -xf - -C /some/path

The blank prompt is expecting the password: ${password}

Consider closing this shell view to remove passwords from scrollback.
"

