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

set -e
set -u

function download () {
    declare to_=${1}
    shift
    declare from_=${1}
    shift
    if which wget &>/dev/null; then
        (
            set -x
            wget "${@}" -O "${to_}" "${from_}"
        )
    elif which curl &>/dev/null; then
        (
            set -x
            curl "${@}" --output "${to_}" "${from_}"
        )
    else
        echo 'ERROR: cannot find either program wget or curl' >&2
        exit 1
    fi
}

download './.bash_profile' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile' "${@}"
download './.bashrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc' "${@}"
download './.bash_logout' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_logout' "${@}"
if which screen &>/dev/null; then
    download './.screenrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc' "${@}"
fi
if which vim &>/dev/null; then
    download './.vimrc' 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc' "${@}"
fi
