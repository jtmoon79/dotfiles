#!/usr/bin/env bash
#
# helper to quickly create a new standalone Python virtualenv with updated modules
#
# $PYTHON can be overriden to use preferred python runtime
# optional $1 to choose the path of the new virtualenv, remaining arguments are
# passed to python

set -eu

(
    set -x
    ${PYTHON-python3} --version
)

if [[ "${1+x}" ]]; then
    VENV_NAME=${1}
    shift
else
    # user did not pass $1 so generate a name for the virtualenv
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
    fi
    if [[ ! "${ID+x}" ]]; then
        ID='-'
    fi
    if [[ ! "${VERSION_ID+x}" ]]; then
        VERSION_ID='-'
    fi
    PYV=$(${PYTHON-python3} --version | cut -f2 -d ' ')
    VENV_NAME=".venv-${PYV}_${ID}-${VERSION_ID}"
fi
VENV_PATH=$(readlink -m -- "${VENV_NAME}" || true)
mkdir -vp -- "${VENV_PATH}"

function exit_err () {
    rm -vrf -- "${VENV_PATH}"
}
trap exit_err EXIT

(
    set -x
    ${PYTHON-python3} -B -m venv --copies --prompt "${VENV_PATH}" "${VENV_PATH}" "${@}"
)
source "${VENV_PATH}/bin/activate"
(
    PYEXEC_=$(which python)
    set -x
    # update baseline of tools to latest
    "${PYEXEC_}" -BOs -m pip install \
        --no-cache-dir --disable-pip-version-check \
        --upgrade wheel pip setuptools
)
echo
echo "New virtualenv at '${VENV_PATH}'"

trap '' EXIT
