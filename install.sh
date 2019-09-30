#!/usr/bin/env bash
#
# install other . (dot) files in a one-liner, for fast setup of a new linux user shell environment
#
# run this file:
#
#    wget -q -O- 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#
#    curl --silent 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' | bash --norc --noprofile
#

set -e
set -u

if which wget &>/dev/null; then
    set -x
    wget "${@}" -O ~/.vimrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc'
    wget "${@}" -O ~/.bash_profile 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile'
    wget "${@}" -O ~/.bashrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc'
    wget "${@}" -O ~/.screenrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc'
elif which curl &>/dev/null; then
    set -x
    curl "${@}" --output ~/.vimrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc'
    curl "${@}" --output ~/.bash_profile 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile'
    curl "${@}" --output ~/.bashrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc'
    curl "${@}" --output ~/.screenrc 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc'
else
    echo 'ERROR: cannot find either program wget or curl' >&2
    exit 1
fi
