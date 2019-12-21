#!/usr/bin/env bash
#
# primitive self-test of .bash_profile, .bashrc using docker images

set -e
set -u

cd "$(dirname -- "${0}")"

HOST_TMP=/tmp/bashrc-test-$(date '+%Y%m%dT%H%M%S')
mkdir -vp "${HOST_TMP}"

function exit_ () {
    rm -vrf -- "${HOST_TMP}"
}
trap exit_ EXIT

CONT_TMP=${HOST_TMP}

# images at https://hub.docker.com/_/bash
images=(
    'bash:3.2'
    'bash:4.0'
    'bash:4.1'
    'bash:4.2'
    'bash:4.3'
    'bash:4.4'
    'bash:5.0'
)

for image in "${images[@]}"; do
    test_pass=${HOST_TMP}/${image//:/_}
    (
    set -x
    docker run \
               -e '__FORCE_INTERACTIVE=true' \
               -e 'color_force=true' \
               -v "${HOST_TMP}:${CONT_TMP}" \
               -v "${PWD}:/root" \
               --rm \
               -it "${image}" \
               sh -c "
        set -x;
        echo 'echo \"PS1:\"; echo \"\${PS1}\"; eval echo \"\\\"\${PS1}\\\"\"; touch \"${test_pass}\"; exit' | bash --login;
"
    )
    echo >&2
    if [[ ! -f "${test_pass}" ]]; then
        echo "ERROR: failed to find pass file '${test_pass}'" >&2
        exit 1
    fi
    echo "Successfully tested using image ${image}" >&2
done

echo "Successfully tested using images ${images[*]}" >&2
