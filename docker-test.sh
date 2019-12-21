#!/usr/bin/env bash
#
# load a bash instance with .bash profiles

set -e
set -u

cd "$(dirname -- "${0}")"

# images at https://hub.docker.com/_/bash
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
