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
    'docker.io/library/bash:3.2'
    'docker.io/library/bash:4.0'
    'docker.io/library/bash:4.1'
    'docker.io/library/bash:4.2'
    'docker.io/library/bash:4.3'
    'docker.io/library/bash:4.4'
    'docker.io/library/bash:5.0'
    'docker.io/library/bash:5.3'
)

for image in "${images[@]}"; do
    name=${image//:/_}
    name=${name//\//_}
    test_pass=${HOST_TMP}/${name}
    echo -e "\e[93mImage ${image} will create file ${test_pass}\e[39m" >&2
    (
    set -x
    docker run \
               --pull=missing \
               -e '__FORCE_INTERACTIVE=true' \
               -e 'color_force=true' \
               -v "${HOST_TMP}:${CONT_TMP}" \
               -v "${PWD}:/root" \
               --rm \
               -it "${image}" \
               sh -c "
        set -eux;
        echo 'set -eu; echo \"PS1:\"; echo \"\${PS1}\"; eval echo \"\\\"\${PS1}\\\"\"; touch \"${test_pass}\"; exit' | bash --login;
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
