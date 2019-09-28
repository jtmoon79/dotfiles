# ~/.bashrc
#
# A mish-mash of bashrc ideas that are worthwhile, some original ideas, others copied.
# This files is expected to be sourced by it's companion ~/.bash_profile
#
# Features:
#   - turn on colors; color_force=true; . ~/.bashrc
#   - prints info about screen and tmux
#   - attempts typical source of /usr/share/bash-completion/bash_completion
#   - optional source from ~/.bashrc.local.pre
#   - optional source from ~/.bashrc.local
#   - optional source from ~/.bash_paths - per-line paths to add to $PATH
#   - safe to use in many varying Unix environments 🤞
#
# Designed from Debian-derived Linux. Attempts to work with other Linux and FreeBSD.
# May be imported multiple times in one shell instance (to allow changing varioius force* switches)
#
# Source at https://gist.github.com/jtmoon79/b92afbaff3a149e0665c0ce13d7a06a0
#
# Set with either command:
#     curl 'https://gist.githubusercontent.com/jtmoon79/b92afbaff3a149e0665c0ce13d7a06a0/raw/.bashrc' --output=~/.bashrc
#     wget -O ~/.bashrc 'https://gist.githubusercontent.com/jtmoon79/b92afbaff3a149e0665c0ce13d7a06a0/raw/.bashrc'
#
# Tested against
# - bash 4.x on Linux Ubuntu 18
# - bash 4.x on Linux Debian 9
# - bash 3.2 on FreeBSD 10
#
# excellent references
#   https://mywiki.wooledge.org/BashFAQ/061 (http://archive.fo/sGtzb)
#   https://misc.flogisoft.com/bash/tip_colors_and_formatting (http://archive.fo/NmIkP)
#   https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/ (http://archive.fo/fktxC)
#   https://github.com/webpro/awesome-dotfiles (http://archive.fo/WuiJW)
#

# If not running interactively, don't do anything
case "$-" in
    *i*)
        ;;
    *)
        return
        ;;
esac

set -u

# .bash_profile may have already created $__sourced_files, only create if not already created
if ! [[ "${__sourced_files+x}" ]]; then
    declare -a __sourced_files=()
fi
__sourced_files[${#__sourced_files[@]}]=${BASH_SOURCE:-}  # note this file!
declare -a __processed_files
__processed_files=()

function __source_file_bashrc () {
    if [[ ! -f "${1}" ]]; then
       return
    fi
    if [[ ! -r "${1}" ]]; then
        return 1  # file exists but is not readable
    fi
    #echo "${PS4:-}source ${1} from ${BASH_SOURCE:-}" >&2
    __sourced_files[${#__sourced_files[@]}]=${1}
    source "${1}"
}

# .bashrc.local for host-specific customizations to run before the remainder of this .bashrc
__source_file_bashrc ~/.bashrc.local.pre

__PATH_original=${PATH}

# note Bash Version
# XXX: presumes single-character versions within string like 'X.Y.…'
declare -i BASH_VERSION_MAJOR=${BASH_VERSION:0:1}  # e.g. '4' in '4.2.10(1)-release'
declare -i BASH_VERSION_MINOR=${BASH_VERSION:2:1}  # e.g. '2' in '4.2.10(1)-release'
export BASH_VERSION_MAJOR \
       BASH_VERSION_MINOR

function what_OS () {
    # attempt to determine what Unix Operating System this is in

    declare os='unknown'
    declare os_flavor=''
    if [[ -f /proc/version ]]; then
        os='Linux'
        if [[ -f /etc/redhat-release ]]; then
             os_flavor='Redhat'
        fi
        echo -n "${os}"
        return
    fi

    declare sysctl_output
    sysctl_output=$(sysctl -n kern.osrelease kern.ostype 2>/dev/null) && os='BSD'
    if [[ "${sysctl_output}" = 'FreeBSD' ]]; then
       os_flavor='FreeBSD'
    fi
    echo -n "${os} ${os_flavor}"

    # TODO: what about MinGW bash? what about cygwin? what about OpenBSD?
}
__OperatingSystem=$(what_OS)

function __replace_str () {
    # Given string $1, replace substring $2 with string $3 then echo the result.
    #
    # This function is the most portable method for doing such. Programs like `sed` and `awk`
    # vary too much or may not be available. Often, a bash substring replacement
    # (e.g. `${foo//abc/123}`) suffices but bash 3.2 does not recognize '\t' as tab character.

    if [[ ${#} != 3 ]]; then
        return 1
    fi
    declare -ir l1=${#1}  # strlen of $1
    declare -ir l2=${#2}  # strlen of $2
    declare -i at=0  # index current
    declare -i atb=0  # index of beginning of next replacement
    declare out=''
    while [[ ${at} -lt ${l1} ]]; do
        if [[ "${1:${at}:${l2}}" == "${2}" ]]; then
            out+=${1:${atb}:${at}-${atb}}${3}
            at=$((at+l2))
            atb=${at}
        else
            at=$((at+1))
        fi
    done
    if [[ ${at} -ne ${atb} ]]; then
        out+=${1:${atb}:${at}-${atb}}
    fi
    echo -n "${out}"
}

function __tab_str () {
    # prepend tabs after each newline
    # optional $1 is tab count
    # optional $2 is replacement string
    declare -ri tab_count=${2:-1}
    declare -r repl=${3:-
}
    __replace_str "${1}" "${repl}" "
$(for ((i = 0; i < tab_count; i++)); do echo -n '	'; done)"
}

function __installed () {
    # are all passed args found in the $PATH?

    declare prog
    for prog in "${@}"; do
        if ! which "${prog}" &>/dev/null; then
            return 1
        fi
    done
}

function env_sorted () {
    # Print environment sorted
    # Accounts for newlines within environment values (common in $LS_COLORS)

    if ! __installed env sort tr; then
        return 1
    fi
    # The programs env and sort may not supported the passed options. Shell option `pipefail` will
    # cause immediate exit if any program fail in the pipeline fails. This function will return
    # that failure code.
    (
        set -o pipefail;
        env --null 2>/dev/null \
           | sort --zero-terminated 2>/dev/null \
           | tr '\000' '\n' 2>/dev/null
    )
}
# Record original environment variables for later diff
__env_0_original=$(env_sorted)

# ===============
# history control
# ===============

# don't put duplicate lines or lines starting with space in the history.
export HISTCONTROL=ignoreboth
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
export HISTSIZE=2000
export HISTFILESIZE=100000
export HISTTIMEFORMAT="%Y%m%dT%H%M%S "
# append to the history file, don't overwrite it
shopt -s histappend

#
# ---------------
# ...
# ---------------

# check the window size after each command and, if necessary, update the values
# of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will match all
# files and zero or more directories and subdirectories.
#shopt -s globstar

# make `less` more friendly for non-text input files, see lesspipe(1)
if [[ -x /usr/bin/lesspipe ]]; then
    eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"
fi

# ==================
# prefer en_US.UTF-8
# ==================

export LANG='en_US.UTF-8'
export LOCALE='UTF-8'
# see https://unix.stackexchange.com/a/87763/21203
export LC_ALL='en_US.UTF-8'

if __installed less; then
    # from `man less`
    #
    #     If neither LESSCHARSET nor LESSCHARDEF is set, but any of the strings
    #     "UTF-8", "UTF8", "utf-8" or "utf8" is found in the LC_ALL, LC_CTYPE or LANG
    #      environment variables, then the default character set is utf-8.
    #
    unset LESSCHARSET
fi

# ==============
# prompt changes
# ==============

# -------------
# prompt color?
# -------------

# NOTE: Colors should be 8-bit as it's the most portable
#       see https://misc.flogisoft.com/bash/tip_colors_and_formatting#terminals_compatibility

function eval_color () {

    # set a fancy prompt
    __color=false
    case "${TERM}" in
        *color)
            __color=true
            ;;
        *)
            case "${COLORTERM:-}" in  # if $TERM=xterm then $COLORTERM should be set
                *color*)
                    __color=true
                    ;;
            esac
    esac

    # default to no color or escape sequences
    __color_prompt=false
    __color_apps=false

    if ${__color}; then
        if [[ -x /usr/bin/tput ]] && /usr/bin/tput setaf 1 &>/dev/null; then
            # We have color support; assume it's compliant with ECMA-48
            # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
            # a case would tend to support setf rather than setaf.)
            __color_prompt=true
            __color_apps=true
        elif [[ -x /usr/bin/tput ]] && [[ "${__OperatingSystem}" =~ 'FreeBSD' ]]; then
           # tput setaf always fails in FreeBSD 10, just try for color
           # https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=210858
            __color_prompt=true
            __color_apps=true
        else
            __color_prompt=false
            __color_apps=false
        fi
    fi

    # if $color_force is defined, then set $__color_prompt according to $color_force truth
    # Force color off
    #      color_force=false . ~/.bashrc
    # Force color on
    #      color_force=true . ~/.bashrc
    if [[ -n "${color_force+x}" ]]; then
        if ${color_force} &>/dev/null; then
            __color_prompt=true
            __color_apps=true
        else
            __color_prompt=false
            __color_apps=false
        fi
    fi

}
eval_color

# -------------
# prompt chroot
# -------------

# set variable identifying the current chroot (used in the prompt below)
if [[ -z "${debian_chroot:-}" ]] && [[ -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ------------
# prompt timer
# ------------

# idea from http://archive.fo/SYU2A
# It is important that __prompt_timer_stop is the last command in the
# $PROMPT_COMMAND.  If there are other commands after it then those
# will be executed and their execution might cause __prompt_timer_start to be
# called again.
# The setting and unset of __prompt_timer_cur is to workaround internecine subshells that occur per
# PROMPT_COMMAND
function __prompt_timer_start () {
    __prompt_timer_cur=${__prompt_timer_cur:-${SECONDS:-0}}
}
function __prompt_timer_stop () {
    # use $__prompt_timer_show for display
    __prompt_timer_show=$((${SECONDS:-0} - __prompt_timer_cur))
    unset __prompt_timer_cur
}
trap '__prompt_timer_start' DEBUG

# ---------------------
# prompt last exit code
# ---------------------

function __prompt_last_exit_code_update () {
    # this function must run first within
    # $PROMPT_COMMAND or else last exit code will be overwritten
    declare -ir last_exit=$?  # first save this value
    __prompt_last_exit_code_banner=
    if [[ ${last_exit} -eq 0 ]]; then
        __prompt_last_exit_code_banner="return code ${last_exit}"  # normal
    else  # non-zero exit code
        if ${__color_prompt}; then
            __prompt_last_exit_code_banner="\001\033[01;31m\002‼ return code ${last_exit}\001\033[00m\002"  # red
        else
            __prompt_last_exit_code_banner="‼ return code ${last_exit}"  # prepend
        fi
    fi
}

function __prompt_last_exit_code_show () {
    echo -en "${__prompt_last_exit_code_banner:-}"
}

declare -r __prompt_bullet_default='‣'  # $ ‣ •
# make sure $prompt_bullet is set
if ! [[ "${prompt_bullet+x}" ]]; then
    prompt_bullet=${__prompt_bullet_default}
fi

function __prompt_live_updates () {
    # special "live" updates that monitor special variables

    # update if necessary
    if [[ "${color_force+x}" ]] && [[ "${__color_force_last:-}" != "${color_force:-}" ]]; then
        eval_color
        __prompt_set  # to be defined below
    fi
    __color_force_last=${color_force:-}

    # if `unset prompt_bullet` occurred then reset to default
    if ! [[ "${prompt_bullet+x}" ]]; then
        prompt_bullet=${__prompt_bullet_default}
    fi
    # update if necessary
    if [[ "${__prompt_bullet_last:-}" != "${prompt_bullet}" ]]; then
        __prompt_set  # to be defined below
    fi
    __prompt_bullet_last=${prompt_bullet}
}

# -------------------
# set title of window
# -------------------

# TODO: record prior title, and then replace it when this login shell exits.
#       currently, login to remote bash overwrites the title, but then never replaces it when it
#       completes
# TODO: consider adjusting title when ssh-ing to other places, e.g. "ssh foo@bar ..." then swap back
#       in.

__title_set_prev=$(echo -ne '\e[22t' 2>/dev/null)  # save the current title? - https://unix.stackexchange.com/a/28520/21203
__title_set_TTY=$(tty 2>/dev/null || true)  # set this once
__title_set_kernel=${__title_set_kernel:-Kernel $(uname -r)}
__title_set_OS=${__title_set_OS:-${__OperatingSystem}}
#__title_set_hostname=$(hostname)
#__title_set_user=${USER:-}
function __title_set {
    # title will only accept one line of text
    echo -en "\033]0;${SHELL:-SHELL not set} TTY ${__title_set_TTY} ${__title_set_kernel} ${__title_set_OS}\007"
}
function __title_reset {  # can be called called in ~/.bash_logout
    echo -en '\033]0;'"${__title_set_prev:-}"'\007'
}
__title_set  # call once, no need to call again

# ============================
# assemble per-prompt commands
# ============================

# -----------------------
# prompt terminal details
# -----------------------

__prompt_terminal_details_tty=$(tty 2>/dev/null || true)  # set once

function __prompt_terminal_details () {
    # Creates a crude table of interesting environment variables.
    # Adds some safety for terminal column width so a narrow terminal does not
    # have a dump of sheared table data
    # TODO: would be cool if the user could update this in "realtime". Maybe it could process a global array
    #       of vars like ('TERM' 'DISPLAY' ...) and evaluate that. Not sure how special case like `tty`
    #       would be handled.
    #       Maybe associative array where key is name and value is how to retrieve the result via `eval`
    #       e.g.
    #           ( "TERM": "${TERM}", "tty": "$(tty)", ...)
    #       or just expect caller to have filled in values with variables to `eval`,
    #       e.g.
    #           ( "TERM": "${TERM}", "tty": "${__prompt_terminal_details_tty}", ...)

    declare row1=''
    declare row2=''
    declare -r s1='┃'  # this will be used for column columns
    declare -r s2='❚'  # this is temporary separator, will not be printed
    declare -r s="${s2}${s1}"

    #if ! [[ "${__prompt_info+x}" ]]; then  # TODO: beginnings of prior TODO
    #    declare -ga __prompt_info=()
    #fi

    declare b=''  # bold on
    declare bf=''  # bold off
    if ${__color_prompt}; then
        b='\e[1m'
        boff='\e[0m'
    fi

    row1+="TERM${s}"
    row2+="${TERM:-not set}${s}"
    if [[ "${color_force+x}" ]]; then
        row1+="color_force${s}"
        row2+="${color_force}${s}"
    fi
    row1+="DISPLAY${s}"
    row2+="${DISPLAY:-not set}${s}"
    if [[ "${COLORTERM+x}" ]]; then
        row1+="COLORTERM${s}"
        row2+="${COLORTERM}${s}"
    fi
    if [[ "${SHLVL+x}" ]]; then
        row1+="SHLVL${s}"
        row2+="${SHLVL}${s}"
    fi
    row1+="tty${s}"
    row2+="${__prompt_terminal_details_tty}${s}"
    if [[ "${STY+x}" ]]; then
        row1+="STY${s}"
        row2+="${STY}${s}"
    fi
    if [[ "${TMUX+x}" ]]; then
        row1+="TMUX${s}"
        row2+="${TMUX}${s}"
    fi
    if [[ "${SSH_TTY+x}" ]]; then
        row1+="SSH_TTY${s}"
        row2+="${SSH_TTY}${s}"
    fi
    if [[ "${SSH_CONNECTION+x}" ]]; then
        row1+="SSH_CONNECTION${s}"
        row2+="${SSH_CONNECTION}${s}"
    fi
    if [[ "${GPG_AGENT_INFO+x}" ]]; then
        row1+="GPG_AGENT_INFO${s}"
        row2+="${GPG_AGENT_INFO}${s}"
    fi
    if [[ "${SSH_AUTH_SOCK+x}" ]]; then
        row1+="SSH_AUTH_SOCK${s}"
        row2+="${SSH_AUTH_SOCK}${s}"
    fi
    if [[ "${SSH_AGENT_PID+x}" ]]; then
        row1+="SSH_AGENT_PID${s}"
        row2+="${SSH_AGENT_PID}${s}"
    fi
    # remove trailing column delimiter, can only be done in Bash versions >= 4
    if [[ ${#row1} -gt 2 ]] && [[ ${BASH_VERSION_MAJOR} -ge 4 ]]; then
        row1=${row1::-2}
    fi
    if [[ ${#row2} -gt 2 ]] && [[ ${BASH_VERSION_MAJOR} -ge 4 ]]; then
        row2=${row2::-2}
    fi

    # safely get the columns wide. if a command fails, $cols will fallback to value 0.
    declare -i cols=$(tput cols 2>/dev/null || true)  # try tput first; tends to be most accurate
    if [[ ${cols} -le 0 ]]; then
        cols=${COLUMNS:-0}  # tput failed, try environment variable COLUMNS
    fi
    if [[ ${cols} -le 0 ]]; then
        cols=80  # for some reason, previous attempts failed. just set to 80
    fi

    # make attempt to print table-like output based on available programs
    # NOTE: column errors when piped as in `printf '%s\n%s' ... | column ...`. Use `echo`.
    # TODO: consider adding color to table? this would need to be done after substring length
    if __installed column; then
        declare table=
        table=$(echo -e "${row1}\n${row2}" | column -t -s "${s2}" -c ${cols})
        table=${table//  ${s1}/ ${s1}}
        # extract row1 and row2 using "back delete" and "front delete" substring manipulation
        row1=${table%%
*}
        row2=${table##*
}
        echo "${row1::${cols}}"
        echo "${row2::${cols}}"
    else  # print without columnar alignment, a bit ugly :-(
        declare row=
        for row in "${row1}" "${row2}"; do
            if __installed tr; then
                echo "${row::${cols}}" | tr "${s2}" '\t'
            else
                row=${row//${s2}/}
                echo "${row::${cols}}"
            fi
        done
    fi

    return 0
}

# ---------------
# prompt git info
# ---------------

function __prompt_git_info () {
    # most directories are not git repositories
    # so make easy checks try to bail out early before getting to __git_ps1; do not let this
    # function be a drag on the system
    if ! __installed git stat; then
        return
    fi
    # do not run `git worktree` on remote system, may take too long
    if [[ '/' != "$(stat '--format=%m' '.' 2>/dev/null)" ]]; then
        return
    fi
    # is this a git worktree?
    if ! git worktree list &>/dev/null; then
        return
    fi

    declare out=''
    # see https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh
    out+="$(export GIT_PS1_SHOWDIRTYSTATE=1
            export GIT_PS1_SHOWSTASHSTATE=1
            export GIT_PS1_SHOWUPSTREAM=1
            if ${__color_prompt}; then
                export GIT_PS1_SHOWCOLORHINTS=1
            fi
           __git_ps1 2>/dev/null)" || true
    #out+="$(git rev-parse --symbolic-full-name HEAD) $()"

    # change to red if repository non-clean; check for literal substring '*='
    if ${__color_prompt}; then
        if [[ "${out}" =~ '*=' ]] || [[ "${out}" =~ '*+' ]]; then
            out='\e[31m'"${out}"'\e[0m'
        elif [[ "${out}" =~ '<)' ]]; then
            out='\e[33m'"${out}"'\e[0m'
        fi
    fi
    # use echo to interpret color sequences here, PS1 will not attempt to interpret this functions
    # output
    echo -en "\ngit:${out}"
}

#
# assemble the prompt pieces
#

function __prompt_set () {
    # set $PS1 with a bunch of good info
    # XXX: is it possible to recheck this on every re-prompt? There are some potential infinite
    #      loops so that would be tricky.
    if ${__color_prompt}; then
        declare color_user='32'  # green
        if [[ 'root' = "$(whoami 2>/dev/null)" ]]; then
            color_user='31'  # red
        fi
        PS1='
\D{%F %T} (last command ${__prompt_timer_show}s; $(__prompt_last_exit_code_show))\[\e[0m\]
\[\e[36m\]$(__prompt_terminal_details)\[\e[32m\]$(__prompt_git_info)\[\e[0m\]${debian_chroot:+(${debian_chroot:-})}
\[\033[01;'"${color_user}"'m\]\u\[\033[039m\]@\[\033[01;36m\]\h\[\033[00m\]:\[\033[01;34m\]\w
'"${prompt_bullet}"'\[\033[00m\] '
    else
        PS1='
\D{%F %T} (last command ${__prompt_timer_show}s; $(__prompt_last_exit_code_show))
$(__prompt_terminal_details) $(__prompt_git_info)${debian_chroot:+(${debian_chroot:-})}
\u@\h:\w
'"${prompt_bullet}"' '
    fi
}
__prompt_set

# order is important; additional commands must between functions __prompt_last_exit_code_update and
# __prompt_timer_stop
PROMPT_COMMAND='__prompt_last_exit_code_update; __prompt_live_updates; __prompt_timer_stop'

# ----------
# misc color
# ----------

if (__installed gcc || __installed 'g++') && ${__color_prompt}; then
    # colored GCC warnings and errors
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
fi

# ==============
# PATH additions
# ==============

function __path_add () {
    # append path $1 to $PATH but only if it is
    # - valid executable directory
    # - not already in $PATH

    declare path=${1}
    if ! ([[ -d "${path}" ]] && [[ -x "${path}" ]]); then  # must be valid executable directory
        return 1
    fi
    # test if any attempts at primitive matching find a match (substring $path within $PATH?)
    # uses primitive substring matching and avoid =~ operator as the path $1 could have regex
    # significant characters
    #      test front
    #      test back
    #      test middle
    if ! (     [[ "${PATH}" = "${PATH##${path}:}" ]] \
            && [[ "${PATH}" = "${PATH%%:${path}}" ]] \
            && [[ "${PATH}" = "${PATH/:${path}:/}" ]]
         )
    then
        return 1
    fi
    echo "${PS4:-}__path_add '${path}'" >&2
    export PATH=${PATH}:${path}
}

function __path_adds()
{
    # if ~/.bash_paths then attempt to add those paths, assuming a path per-line
    # add any paths passed to this function

    declare path=
    if [[ -r ~/.bash_paths ]]; then
        __processed_files[${#__processed_files[@]}]=~/.bash_paths
        while read -r path; do
            __path_add "${path}"
        done < ~/.bash_paths
    fi
    for path in "${@}"; do
        __path_add "${path}"
    done
}
__path_adds "${HOME}/bin"

# =======
# aliases
# =======

function __alias_safely () {
    # create alias if it does not obscure a program in the $PATH
    if __installed "${1}"; then
        return 1
    fi
    alias "${1}"="${2}"
}

function __alias_check () {
    # create alias if running the alias succeeds
    (cd ~ && ${2}) &>/dev/null || return
    alias "${1}"="${2}"
}

function __alias_safely_check () {
    # create alias if it does not obscure a program in the $PATH and running the alias succeeds
    if __installed "${1}"; then
        return 1
    fi
    (cd ~ && ${2}) &>/dev/null || return
    alias "${1}"="${2}"
}

# -------------
# color aliases
# -------------

# enable color support of ls and also add handy aliases
if ${__color_apps} && [[ -x /usr/bin/dircolors ]]; then
    if test -r ~/.dircolors; then
        eval "$(/usr/bin/dircolors -b ~/.dircolors)"
    else
        eval "$(/usr/bin/dircolors -b)"
    fi

    __alias_check ls 'ls --color=auto'
    if __installed dir; then
        __alias_check dir 'dir --color=auto'
    fi
    if __installed vdir; then
        __alias_check vdir 'vdir --color=auto'
    fi
fi

if ${__color_apps}; then
    # various grep interfaces found on Ubuntu 18
    # since each grep will be run, for stability, confine search to /usr/bin and /bin
    for __grep_path in \
       /usr/bin/{bzgrep,dgrep,grep,egrep,fgrep,xzgrep,zegrep,zfgrep,zgrep,zipgrep} \
       /bin/{bzgrep,dgrep,grep,egrep,fgrep,xzgrep,zegrep,zfgrep,zgrep,zipgrep}
    do
       __grep_base=${__grep_path##*/}  # get basename
       # run simplest match with the grep program to make sure it understands option '--color=auto'
       if __installed "${__grep_path}" \
         && [[ "$(which "${__grep_base}" 2>/dev/null)" = "${__grep_path}" ]] \
         && (echo '' | "${__grep_path}" --color=auto '' &>/dev/null); then
           alias "${__grep_base}"="${__grep_path} --color=auto"
       fi
    done
    unset __grep_path
    unset __grep_base
fi

# -------------
# other aliases
# -------------

__alias_safely_check l 'ls -lA'
__alias_safely_check ll 'ls -lA'
__alias_safely_check la 'ls -A'
__alias_safely_check ltr 'ls -Altr'
__alias_safely_check whence 'type -a'  # where, of a sort
__alias_safely_check psa 'ps -ef --forest'

if __installed git; then
    __alias_safely gitb 'git branch -avv'
    __alias_safely gitf 'git fetch -av'
    __alias_safely gits 'git status -vv'
fi
__alias_safely_check envs env_sorted
if __installed mount sort column; then
    __alias_safely_check mnt 'mount | sort -k3 | column -t'
fi

# ============
# self updater
# ============

function __download_from_to () {
    declare -r url=${1}
    shift
    declare -r path=${1}
    shift
    if __installed wget; then
        wget "${@}" -O "${path}" "${url}"
    elif __installed curl; then
        curl "${@}" --output "${path}" "${url}"
    else
        return 1
    fi
}

function __update_dotbashprofile () {
    __download_from_to 'https://gist.githubusercontent.com/jtmoon79/863a3c42a41f03729023a976bbcd97f0/raw/.bash_profile' "${HOME}/.bash_profile" "${@}"
}

function __update_dotbashrc () {
    __download_from_to 'https://gist.githubusercontent.com/jtmoon79/b92afbaff3a149e0665c0ce13d7a06a0/raw/.bashrc' "${HOME}/.bashrc" "${@}"
}

function __update_dotvimrc () {
    __download_from_to 'https://gist.githubusercontent.com/jtmoon79/e6bece129386dacddbe2256d0e5fdca3/raw/.vimrc' "${HOME}/.vimrc" "${@}"
}

function __update_dotscreenrc () {
    __download_from_to 'https://gist.githubusercontent.com/jtmoon79/4531d3ec6a2d7c574bda08ca533920e5/raw/.screenrc' "${HOME}/.screenrc" "${@}"
}

function __update_dots () {
    # install other . (dot) files in a one-liner, for fast setup or update of a new linux user shell environment
    # may pass wget/curl parameters to like --no-check-certificate or --insecure
    __update_dotbashprofile "${@}"
    __update_dotbashrc "${@}"
    __update_dotvimrc "${@}"
    __update_dotscreenrc "${@}"
}


# =========================
# source other bashrc files
# =========================

# Do not source ~/.bash_profile as that will source ~/.bashrc (circular dependency)

# .bashrc.local for host-specific customizations

__source_file_bashrc ~/.bashrc.local
__source_file_bashrc ~/.bash_aliases

if ! shopt -oq posix; then
    __source_file_bashrc /usr/share/bash-completion/bash_completion
    __source_file_bashrc /etc/bash_completion
fi

# ====================================================
# print information this .bashrc has done for the user
# ====================================================

# TODO: show newly introduced environment variables
#       But how to diff input from stdin? Creating temporary files to feed to diff is too risky for
#       a startup script.

function infob () {
    # echo information about this shell instance for the user with pretty formatting and indentation

    declare __env_1_now=$(env_sorted)
    declare b=''
    declare boff=''
    if ${__color_prompt}; then
        b='\e[1m'
        boff='\e[0m'
    fi

    # echo information about this bash
    echo "\
Using bash ${BASH_VERSION}, process ID $$
"
    # echo aliases
    echo -e "\
${b}Aliases in this shell (alias):${boff}

	$(__replace_str "$(__replace_str "$(alias)" 'alias ' '')" '
' '
	')
" >&2

    # echo information functions available
    echo -e "\
${b}Functions in this shell (declare -F):${boff}

$(__replace_str "$(declare -F)" 'declare -f ' '	')
" >&2

    # echo information about interesting enviroment variables
    echo -e "\
${b}New Environment Variables:${boff}

	TERM='${TERM}'
	HISTCONTROL='${HISTCONTROL}'
	HISTSIZE='${HISTSIZE}'
	HISTFILESIZE='${HISTFILESIZE}'
	HISTTIMEFORMAT='${HISTTIMEFORMAT}'
	LANG='${LANG}'
	LC_ALL='${LC_ALL}'
	LOCALE='${LOCALE:-NOT SET}'
	BASH_VERSION_MAJOR='${BASH_VERSION_MAJOR}'
	BASH_VERSION_MINOR='${BASH_VERSION_MINOR}'
	debian_chroot='${debian_chroot:-NOT SET}'
	prompt_bullet='${prompt_bullet:-NOT SET}'
	color_force=${color_force:-NOT SET}
	__color=${__color:-NOT SET}
	__color_prompt=${__color_prompt:-NOT SET}
	__color_apps=${__color_apps:-NOT SET}
	__OperatingSystem='${__OperatingSystem}'
	__env_0_original=… (too large to print)
"

    # echo $__sourced_files
    echo -e "\
${b}Files Sourced:${boff}

$(for src in "${__sourced_files[@]}"; do echo "	${src}"; done)
"

    # echo $__processed_files if any
    if [[ ${#__processed_files[@]} -gt 0 ]]; then
        echo -e "\
${b}Files Processed:${boff}

$(for src in "${__processed_files[@]}"; do echo "	${src}"; done)
"
    fi

    # echo multiplexer server status
    if [[ -n "${TMUX:-}" ]] && __installed tmux; then
        echo -e "\
${b}tmux Settings:${boff}

	tmux ID: $(tmux display-message -p '#S')
	tmux sessions:
		$(__tab_str "$(tmux list-sessions)" 2)
"
    elif [[ -n "${STY:-}" ]] && __installed screen; then
        declare __screen_list=$(screen -list 2>/dev/null)
        if __installed tail; then
            __screen_list=$(echo -n "${__screen_list}" | tail -n +2)
            __screen_list=${__screen_list:1}
        fi
        echo -e "\
${b}screen Settings:${boff}

	screen: $(screen --version)
	screen ID: ${STY}
	screen Sessions:
		$(__tab_str "${__screen_list}")
"
    fi

    # echo $PATHs
    echo -e "\
${b}Paths:${boff}

	$(__tab_str "${PATH}" 1 ':')
"

    # echo information about other users, system uptime
    if __installed w; then
        echo -e "\
${b}System and Users (w):${boff}

	$(__tab_str "$(w)")
"
    fi

    # echo special features in a special way
    echo -e "\
${b}Special Features of this .bashrc:${boff}

	Force your preferred multiplexer by setting ${b}force_multiplexer${boff} to 'tmux' or 'screen' in file ~/.bash_profile.local (requires new bash login)
	Update a dot file by calling one of the functions:
		${b}__update_dotbashprofile${boff}  # update ~/.bash_profile
		${b}__update_dotbashrc${boff}       # update ~/.bashrc
		${b}__update_dotscreenrc${boff}     # update ~/.screenrc
		${b}__update_dotvimrc${boff}        # update ~/.vimrc
		${b}__update_dots${boff}            # update all of the above
	Override color by changing ${b}color_force${boff} to ${b}true${boff} or ${b}false${boff}.
	Override prompt by changing ${b}prompt_bullet${boff} which is currently '${b}${prompt_bullet}${boff}'.
"
}

infob

set +u

