#!/usr/bin/env bash
#
# load a bash instance with .bash profiles

set -e
set -u

cd "$(dirname -- "${0}")"

if [[ "${1-}" = '-h' || "${1-}" = '--help' || "${1-}" = '-?' ]]; then
    echo "usage:
    $(basename -- "${0}") [bash-image]

    where bash-image is a docker hub bash image, e.g. 'bash:4.0' or 'bash:latest' or 'bash'

about:

    For testing the dot files with different versions of bash.
    Run a bash login shell using bash dot files within a docker container.

    Public docker hub bash images are at https://hub.docker.com/_/bash
" >&2
    exit 1
fi

IMAGE=${1-'bash:4.0'}
DTNOW=$(date '+%Y%m%dT%H%M%S')
HOSTNAME=${IMAGE/./-}-${DTNOW}
HOSTNAME=${HOSTNAME/:/-}

set -x
exec \
    docker \
        run \
            -e 'color_force=true' \
            -e 'prompt_bullet=→' \
            -v "${PWD}:/root" \
            --hostname "${HOSTNAME}" \
            --name "${HOSTNAME}" \
            --rm \
            -it "${IMAGE}" \
            bash --login
