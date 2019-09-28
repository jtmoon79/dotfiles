# .bash_profile
#
# lastest version at
#   https://gist.github.com/jtmoon79/863a3c42a41f03729023a976bbcd97f0/edit
#
# Features:
#   - tested in a variety of environments; Debian, openSUSE, FreeBSD using various bash versions
#   - attempts to play well with screen or tmux
#   - handles graphical and non-graphical environments
#
# TODO: this calls multiplexers backwards
#       this file is processed by bash instance and in turn starts a multiplexer instance
#       this should occur in the opposite way; start a multiplexer instance and then start a bash instance.
#       is that reasonreasonably possible?

declare -a __sourced_files=()
__sourced_files[0]=${BASH_SOURCE:-}  # note this file!

function __source_file_bashprofile() {
    if [[ ! -f "${1}" ]]; then
       return
    fi
    if [[ ! -r "${1}" ]]; then
        return 1  # file exists but is not readable
    fi
    # help the user understand what is happening
    echo "${PS4:-}source ${1} from ${BASH_SOURCE:-}" >&2
    __sourced_files[${#__sourced_files[@]}]=${1}
    source "${1}"
}

# useful for setting $force_multiplexer
__source_file_bashprofile ~/.bash_profile.local

# inform the local X server to allow this shell instance to launch GUI programs
# see https://bugs.launchpad.net/ubuntu/+source/gedit/+bug/1449748/comments/10
if [[ "$-" =~ 'i' ]] && [[ -n "${DISPLAY:-}" ]] && which xhost &>/dev/null; then
    # XXX: this is lax security, how to make the X server allowance more restricted?
    xhost +local:
fi

# try different terminal multiplexers
# TODO: BUG: race condition: multiple shells starting at once will attach to the same detached session (e.g. in Terminator)
if [[ "$-" =~ 'i' ]] && [[ -z "${TMUX+x}" ]] && [[ -z "${STY+x}" ]]; then
    # try tmux
    # added by jtmoon from https://wiki.archlinux.org/index.php/Tmux#Start_tmux_on_every_shell_login
    if [[ "${force_multiplexer+x}" = 'tmux' ]] || (which tmux &>/dev/null && ! [[ "${force_multiplexer+x}" ]]); then
        # try to attach-session to detached tmux session, otherwise create new-session
        tmux_detached=
        if (which grep && which cut) &>/dev/null; then
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
            tmux_detached=$(tmux ls | grep -v -m1 -Fe 'attached' | grep -v -Fe 'no server running' | cut -d: -f1) 2>/dev/null
        fi
        if [[ -z "${tmux_detached}" ]] ; then
             # a detached session not present so create a new session
            __source_file_bashprofile ~/.bashrc
            echo "${PS4:-}exec tmux new-session" >&2
            exec tmux new-session
        else
            # detached session available so attach to that session
            echo "${PS4:-}exec tmux attach-session -t '${tmux_detached}'" >&2
            exec tmux attach-session -t "${tmux_detached}"
        fi
    # try screen
    # removed check [ -z "${STY+x}" ]
    elif [[ "${force_multiplexer+x}" = 'screen' ]] || (which screen &>/dev/null && ! [[ "${force_multiplexer+x}" ]]); then
        # try to attach to Detached session, otherwise start a new session
        screen_detached=
        # XXX: if screen does start a new instance, then `__source_file_bashprofile .bashrc` else do not
        #      how to determine ahead of time?
        if (which grep && which tr && which cut) &>/dev/null; then
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

            screen_detached=$(screen -list | grep -m1 -Fe '(Detached)' | tr -s '[:blank:]' | cut -f2)
        fi
        if [[ -z "${screen_detached}" ]]; then
            # no detached screen, start new screen
            __source_file_bashprofile ~/.bashrc
            # without `-l` this will break logins
            echo "${PS4:-}exec screen -l -RR -U" >&2
            exec screen -l -RR -U
        else
            # found detached screen
            echo "${PS4:-}exec screen -r '${screen_detached}'" >&2
            exec screen -r "${screen_detached}"
        fi
    fi
fi

__source_file_bashprofile ~/.bashrc

