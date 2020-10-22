#!/usr/bin/env bash
#
# Install other . (dot) files in a one-liner, for fast setup of a new Unix user shell environment.
# Parameters passed to this script will be passed as options to wget or curl, prefers curl.
#
# To run this file:
#
#    curl --silent 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#
#    wget -q -O- 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#
# Or, if options must be passed, like `--insecure` or `--no-check-certificate`:
#
#    curl 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' --output /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh && rm /tmp/install.sh
#
#    wget -O /tmp/install.sh 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' && chmod +x /tmp/install.sh && /tmp/install.sh && rm /tmp/install.sh
#

set -e
set -u

# XXX: older versions of bash do not like the "${@-}" expansion when there are no arguments

function download () {
    # $1 download to
    # $2 download from
    # function parameters beyond $2 will be passed to wget or curl as options
    declare -r to_=${1}
    shift
    declare -r from_=${1}
    shift
    if which curl &>/dev/null; then
        if [[ ${#} -gt 0 ]]; then
        (
            set -x
            curl "${@-}" --output "${to_}" "${from_}"
        )
        else
        (
            set -x
            curl --output "${to_}" "${from_}"
        )
        fi
    elif which wget &>/dev/null; then
        if [[ ${#} -gt 0 ]]; then
        (
            set -x
            wget "${@-}" -O "${to_}" "${from_}"
        )
        else
        (
            set -x
            wget -O "${to_}" "${from_}"
        )
        fi
    else
        echo 'ERROR: cannot find either program wget or curl' >&2
        return 1
    fi
}

declare -r URL='https://raw.githubusercontent.com/jtmoon79/dotfiles/master'

if [[ ${#} -gt 0 ]]; then
    download './.bash_profile' "${URL}/.bash_profile" "${@-}"
    download './.bashrc' "${URL}/.bashrc" "${@-}"
    download './.bash_logout' "${URL}/.bash_logout" "${@-}"
    if which screen &>/dev/null; then
        download './.screenrc' "${URL}/.screenrc" "${@-}"
    fi
    if which vim &>/dev/null; then
        download './.vimrc' "${URL}/.vimrc" "${@-}"
    fi
else
    download './.bash_profile' "${URL}/.bash_profile"
    download './.bashrc' "${URL}/.bashrc"
    download './.bash_logout' "${URL}/.bash_logout"
    if which screen &>/dev/null; then
        download './.screenrc' "${URL}/.screenrc"
    fi
    if which vim &>/dev/null; then
        download './.vimrc' "${URL}/.vimrc"
    fi
fi
