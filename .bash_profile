# .bash_profile
#
# lastest version at
#   https://github.com/jtmoon79/dotfiles/blob/master/.bash_profile
#
# Features:
#   - tested in a variety of environments; Debian, openSUSE,
#     FreeBSD using various bash versions
#   - attempts to play well with screen or tmux
#   - handles graphical and non-graphical environments
#
# Anti-Features:
#   - not POSIX compliant!
#
# Works best with companion .bashrc.
#
# XXX: this calls multiplexers backwards
#      this file is processed by bash instance and which in-turn starts a multiplexer instance
#      this should occur in the opposite way; start a multiplexer instance and then start a bash
#      instance. But is that even *reasonably* possible?
#

set -u

if [[ -z "${__bash_start_beg_time-}" ]]; then
    __bash_start_beg_time=${EPOCHREALTIME-}
    if [[ -z "${__bash_start_beg_time-}" ]]; then
        __bash_start_beg_time=${SECONDS}
    fi
fi

# If not running interactively, do not print.
__bash_profile_verbose=false
case "$-" in
    *i*)
        __bash_profile_verbose=true
        ;;
    *)
        ;;
esac

if ! [[ "${__bash_sourced_files+x}" ]]; then
    declare -a __bash_sourced_files=()
fi

function __bash_installed () {
    # are all passed args found in the $PATH?
    if ! which which &>/dev/null; then
        return 1
    fi
    declare prog=
    for prog in "${@}"; do
        if ! which "${prog}" &>/dev/null; then
            return 1
        fi
    done
    return 0
}

function readlink_portable () {
    # make best attempt to use the available readlink (or realpath) but do not
    # fail if $1 is not found.
    # readlink options among different readlink implementations (GNU coreutils and BSD) vary.
    # So make sure readlink exists and understands the options passed before
    # using it.
    declare out=

    if __bash_installed readlink; then
        # GNU coreutils readlink supports '-e'
        if out=$(readlink -n -e -- "${@}" 2>/dev/null); then
            echo -n "${out}"
            return 0
        # BSD readlink supports '-f'
        elif out=$(readlink -n -f -- "${@}" 2>/dev/null); then
            echo -n "${out}"
            return 0
        # old versions of readlink may not support '-n'
        elif out=$(readlink -e -- "${@}" 2>/dev/null); then
            echo -n "${out}"
            return 0
        fi
    fi
    # nothing has worked, just echo
    echo -n "${@}"
}

function __bash_profile_path_dir_ () {
    # do not assume this is run from path $HOME. This allows loading companion .bash_profile and
    # .bashrc from different paths.
    declare path=${BASH_SOURCE:-}/..
    if __bash_installed dirname; then
        path=$(dirname -- "${BASH_SOURCE:-}")
    fi
    if ! [[ -d "${path}" ]]; then
        path=~  # in case something is wrong, fallback to ~
    fi
    echo -n "${path}"
}

__bash_profile_path_dir=$(__bash_profile_path_dir_)

function __bash_profile_source_file () {
    declare sourcef=
    sourcef=$(readlink_portable "${1}")
    if ! [[ -f "${sourcef}" ]]; then
        return 1
    fi
    if ! [[ -r "${sourcef}" ]]; then
        return 1  # file exists but is not readable
    fi
    # help the user understand what is happening
    if ${__bash_profile_verbose}; then
        echo "${PS4-}source ${sourcef} from ${BASH_SOURCE:-}" >&2
    fi
    source "${sourcef}"
    __bash_sourced_files[${#__bash_sourced_files[@]}]=${sourcef}
}

__bash_sourced_files[${#__bash_sourced_files[@]}]=$(readlink_portable "${BASH_SOURCE:-}")  # note *this* file!

# useful for setting $force_multiplexer
__bash_profile_source_file "${__bash_profile_path_dir}/.bash_profile.local"

# try different terminal multiplexers tmux and screen but only if not already within a multiplexer
# BUG: race condition: multiple shells starting at once will attach to the same detached
#      session (e.g. in Terminator)
if [[ "$-" =~ 'i' ]] \
&& [[ -z "${TMUX+x}" ]] \
&& [[ -z "${STY+x}" ]] \
&& ( [[ "${force_multiplexer+x}" ]] && [[ "${force_multiplexer-}" != '' ]] )  # `force_multiplexer` is defined and not empty
then
    # try tmux
    # taken from https://wiki.archlinux.org/index.php/Tmux#Start_tmux_on_every_shell_login
    if [[ "${force_multiplexer-}" = 'tmux' ]] && __bash_installed tmux; then
        # try to attach-session to detached tmux session, otherwise create new-session
        __bash_profile_tmux_detached=
        if __bash_installed grep cut; then
            # get the tmux ID of a deattached session
            #
            # based on `tmux ls` output like:
            #
            #$ tmux ls
            #0: 1 windows (created Wed Sep 18 17:05:51 2019) [157x41] (attached)
            #1: 1 windows (created Wed Sep 18 17:06:39 2019) [157x41] (attached)
            #2: 1 windows (created Wed Sep 18 17:06:57 2019) [80x23]
            #
            # or:
            #
            #$ tmux ls
            #no server running on /tmp/tmux-4261/default
            #
            # TODO: what about tmux in non-English locale?
            #
            __bash_profile_tmux_detached=$(tmux ls | grep -v -m1 -Fe 'attached' | grep -v -Fe 'no server running' | cut -d: -f1) 2>/dev/null
        fi
        if [[ -z "${__bash_profile_tmux_detached}" ]] ; then
             # a detached session not present so create a new session
            #__bash_profile_source_file "${__bash_profile_path_dir}/.bashrc"
            echo "${PS4-}exec tmux new-session" >&2
            sleep 0.1
            exec tmux new-session
        else
            # detached session available so attach to that session
            echo "${PS4-}exec tmux attach-session -t '${__bash_profile_tmux_detached}'" >&2
            sleep 0.1
            exec tmux attach-session -t "${__bash_profile_tmux_detached}"
        fi
    # try screen
    elif [[ "${force_multiplexer-}" = 'screen' ]] && __bash_installed screen; then
        # try to attach to Detached session, otherwise start a new session
        __bash_profile_screen_detached=
        # XXX: if screen does start a new instance, then `__bash_profile_source_file .bashrc` else do
        #      not how to determine ahead of time?
        if __bash_installed grep tr cut; then
            # based on `screen -list` output like:
            #
            #There are screens on:
            #        11407.pts-2.hostA (09/18/2019 04:27:30 PM)        (Attached)
            #        16278.pts-16.hostA        (09/17/2019 05:12:21 PM)        (Attached)
            #        30275.pts-4.hostA (09/17/2019 01:54:16 PM)        (Attached)
            #        30274.pts-3.hostA (09/17/2019 01:54:16 PM)        (Attached)
            #        30260.pts-0.hostA (09/17/2019 01:54:16 PM)        (Attached)
            #        9010.pts-6.hostA  (09/16/2019 01:09:42 PM)        (Attached)
            #        8993.pts-9.hostA  (09/16/2019 01:09:42 PM)        (Detached)
            #        8991.pts-8.hostA  (09/16/2019 01:09:42 PM)        (Attached)
            #        8986.pts-1.hostA  (09/16/2019 01:09:42 PM)        (Attached)
            #9 Sockets in /run/screen/S-user.
            #
            # TODO: what about screen in non-English locale?
            #
            __bash_profile_screen_detached=$(screen -list | grep -m1 -Fe '(Detached)' | tr -s '[:blank:]' | cut -f2)
        fi
        if [[ -z "${__bash_profile_screen_detached}" ]]; then
            # no detached screen, start new screen
            __bash_profile_source_file "${__bash_profile_path_dir}/.bashrc"
            # without `-l` this will break logins
            echo "${PS4-}exec screen -l -RR -U" >&2
            sleep 0.1
            exec screen -l -RR -U
        else
            # found detached screen
            echo "${PS4-}exec screen -r '${__bash_profile_screen_detached}'" >&2
            sleep 0.1
            exec screen -r "${__bash_profile_screen_detached}"
        fi
    fi
fi

# inform the local X server to allow this shell instance to launch GUI programs
# see https://bugs.launchpad.net/ubuntu/+source/gedit/+bug/1449748/comments/10
if [[ "$-" =~ 'i' ]] && [[ -n "${DISPLAY:-}" ]] && __bash_installed xhost &>/dev/null; then
    # XXX: this is lax security, how to make the X server allowance more restricted?
    #      see https://wiki.archlinux.org/index.php/Xhost#Usage
    xhost +local:
fi

__bash_profile_source_file "${__bash_profile_path_dir}/.bashrc"
