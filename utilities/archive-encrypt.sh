#!/usr/bin/env bash
#
# Quick imperfect script to tar a path and 7zip compress+encrypt the tar.
# Useful for quick encrypted backups.
# Do keep in mind, any user on a *nix system can see the full command line of
# other running commands (and 7z requires passing the password on the command
# line).
#
# Designed against 7-zip 16.02 and GNU tar 1.29

set -e
set -u
set -o pipefail

BACKUP_DIR=${BACKUP_DIR-${HOME}/backups}

function backup_name_tar() {
    echo -n "${BACKUP_DIR}/${1}__$(date +%Y%m%d).tar"
}

if [[ ${#} != 1 && ${#} != 2 ]] || [[ "${1:-}" == '--help' ]]; then
    name="$(backup_name_tar '$1').7z"
    echo "usage:
    ${0} TARGET [BACKUP_DIR]

Tar and 7zip a TARGET directory path or file.
Tar to preserve filesystem permissions and layout. 7zip then compresses and
encrypts.
Requires entering a password on stdin for the 7zip encryption.

Backup to an archive file based on the host and path passed,
e.g. '${name}'

Default destination for encrypted archive BACKUP_DIR is
'${BACKUP_DIR}'

Later, the archive will decrypt with command:

    7z e '${name}' -so | tar -xvf - -C /some/path

The 7z command will wait for the password on stdin.
" >&2
    exit 1
fi

TARGET=${1}
if [[ ! -e "${TARGET}" ]]; then
    echo "ERROR: TARGET '${TARGET}' does not exist" >&2
    exit 1
fi
#if [[ ! -d "${TARGET}" ]]; then
#    echo "ERROR: TARGET is not a directory '${TARGET}'" >&2
#    exit 1
#fi
readonly TARGET

BACKUP_DIR=${2:-${BACKUP_DIR}}
readonly BACKUP_DIR

for prog in tar 7z; do
    if ! which "${prog}" &>/dev/null; then
        echo "ERROR: cannot find ${prog} in PATH" >&2
        exit 1
    fi
done

name=$(basename -- "$(readlink -f -- "${TARGET}")")
archive_tar=$(backup_name_tar "${name}")
archive_tar7z="${archive_tar}.7z"

read -p "Enter the 7z archive password: " -s password
echo

if [[ -d "${TARGET}" ]] || [[ -L "${TARGET}" ]]; then
    declare -a tar_args=(
        "--directory=${TARGET}"
        '.'
    )
elif [[ -f "${TARGET}" ]]; then
    declare -a tar_args=(
        "--directory=$(dirname -- "${TARGET}")"
        `#"--add-file=${TARGET}"`
        "$(basename -- "${TARGET}")"
    )
else
    echo "ERROR: bad path type '${TARGET}'" >&2
    exit 1
fi

(
# success or failure, remove the temporary .tar file
function exit_() {
    if which shred &>/dev/null; then
        shred -z -- "${archive_tar}"
    fi
    rm -vf -- "${archive_tar}"
}
trap exit_ EXIT

(
set -x

# create the .tar
tar \
  --create \
  --preserve-permissions \
  --sort=name \
  --acls --xattrs \
  --one-file-system \
  --ignore-failed-read \
  --format=pax \
  --file="${archive_tar}" \
  "${tar_args[@]}"

# list contents of the .tar
tar \
  -t \
  -f "${archive_tar}" >/dev/null
)

declare -a s7z_args=(
  '-t7z'
  '-m0=lzma2'
  '-mx=9'
  '-mfb=64'
  '-md=32m'
  '-ms=on'
  '-mhe=on'
  "${archive_tar7z}"
  "${archive_tar}"
)

# compress+encrypt the archive
# XXX:password on a command-line is not good but that is how 7z was designed
echo "${PS4-}7z a -p****" "${s7z_args[@]}" >&2
7z a \
  -p"${password}" \
  "${s7z_args[@]}"

# list archive details, also a sanity check
# XXX:password on a command-line is not good but that is how 7z was designed
echo "${PS4-}7z l -p****" -slt "${archive_tar7z}" >&2
7z l \
  -p"${password}" \
  -slt \
  "${archive_tar7z}"
)

echo "Success!" >&2
echo "Restore archive '$(basename -- "${archive_tar7z}")' with command:

    7z e '${archive_tar7z}' -so | tar -xvf - -C /some/path

The blank prompt will be expecting the password.
" | tee "${archive_tar7z}.info" >&2
