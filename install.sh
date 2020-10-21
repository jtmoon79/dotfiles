#!/usr/bin/env bash
#
# install other . (dot) files in a one-liner, for fast setup of a new Unix user shell environment
# parameters passed to this script will be passed as options to wget or curl
#
# run this file:
#
#    wget -q -O- 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#
#    curl --silent 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#
# or
#
#    wget -O /tmp/script.sh 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' && chmod -v +x /tmp/script.sh && /tmp/script.sh
#
#    curl 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' --output /tmp/script.sh && chmod -v +x /tmp/script.sh && /tmp/script.sh
#
# BUG: bash 3 will fail if not passed a parameters.
#      workaround is to pass --no-check-certificate or --insecure to /tmp/script.sh
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

if [[ ${#} -gt 0 ]]; then
    download './.bash_profile' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile' "${@-}"
    download './.bashrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc' "${@-}"
    download './.bash_logout' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_logout' "${@-}"
    if which screen &>/dev/null; then
        download './.screenrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc' "${@-}"
    fi
    if which vim &>/dev/null; then
        download './.vimrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc' "${@-}"
    fi
else
    download './.bash_profile' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile'
    download './.bashrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc'
    download './.bash_logout' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_logout'
    if which screen &>/dev/null; then
        download './.screenrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc'
    fi
    if which vim &>/dev/null; then
        download './.vimrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc'
    fi
fi
