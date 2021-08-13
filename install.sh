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
#    curl --insecure 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' --output /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh --insecure && rm /tmp/install.sh
#
#    wget -O /tmp/install.sh --no-check-certificate 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install.sh' && chmod +x /tmp/install.sh && /tmp/install.sh --no-check-certificate && rm /tmp/install.sh
#

set -e
set -u

# XXX: older versions of bash do not like the "${@-}" expansion when there are no arguments
#      must do tedious workaround of first testing ${#}

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

function install_dotfiles() {
    declare fn=
    if [[ ${#} -gt 0 ]]; then
        fn='.bash_profile'
        download "./${fn}" "${URL}/${fn}" "${@-}"
        fn='.bash_profile.local'
        if ! [[ -e "./${fn}" ]]; then
            download "./${fn}" "${URL}/${fn}" "${@-}"
        fi
        fn='.bashrc'
        download "./${fn}" "${URL}/${fn}" "${@-}"
        fn='.bashrc.builtins.post'
        download "./${fn}" "${URL}/${fn}" "${@-}"
        fn='.bashrc.local.post'
        if ! [[ -e "${fn}" ]]; then
            download "./${fn}" "${URL}/${fn}" "${@-}"
        fi
        fn='.bash_logout'
        download "./${fn}" "${URL}/${fn}" "${@-}"
        if which screen &>/dev/null; then
            fn='.screenrc'
            download "./${fn}" "${URL}/${fn}" "${@-}"
        fi
        if which vim &>/dev/null; then
            fn='.vimrc'
            download "./${fn}" "${URL}/${fn}" "${@-}"
        fi
    else
        fn='.bash_profile'
        download "./${fn}" "${URL}/${fn}"
        fn='.bash_profile.local'
        if ! [[ -e "./${fn}" ]]; then
            download "./${fn}" "${URL}/${fn}"
        fi
        fn='.bashrc'
        download "./${fn}" "${URL}/${fn}"
        fn='.bashrc.builtins.post'
        download "./${fn}" "${URL}/${fn}"
        fn='.bashrc.local.post'
        if ! [[ -e "${fn}" ]]; then
            download "./${fn}" "${URL}/${fn}"
        fi
        fn='.bash_logout'
        download "./${fn}" "${URL}/${fn}"
        if which screen &>/dev/null; then
            fn='.screenrc'
            download "./${fn}" "${URL}/${fn}"
        fi
        if which vim &>/dev/null; then
            fn='.vimrc'
            download "./${fn}" "${URL}/${fn}"
        fi
    fi
}

if [[ ${#} -gt 0 ]]; then
    install_dotfiles "${@-}"
else
    install_dotfiles
fi
