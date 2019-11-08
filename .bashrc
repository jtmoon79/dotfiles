# .bashrc
#
# A mish-mash of bashrc ideas that are worthwhile, some original ideas, others copied.
# This files is expected to be sourced by it's companion ./.bash_profile
#
# Features:
#   - prints context info on startup
#   - prompt prints: timer, return code, datetime, table of variables (adjustable)
#   - allows "live" modification of some prompt features
#   - allows override of various features via ./.bashrc.local.pre
#   - optional source from ./.bashrc.local.pre, ./.bashrc.local, ./.bashrc.local.post
#   - optional source from ./.bash_paths - per-line paths to add to $PATH
#   - attempts sourcing of /usr/share/bash-completion/bash_completion
#   - safe to use in many varying Unix environments 🤞
#
# Designed from Debian-derived Linux. Attempts to work with other Linux and Unix in varying
# envionrments. Avoids absolute reliance on tools like `grep`, `sed`, etc. because those tools vary
# too much or are not available.
#
# Source at https://github.com/jtmoon79/dotfiles/blob/master/.bashrc
# Install using https://github.com/jtmoon79/dotfiles/blob/master/install.sh
#
# (sometimes) tested against
# - bash 4.x on Linux Ubuntu 18
# - bash 4.x on Linux Debian 9
# - bash 3.2 on FreeBSD 10
#
# Excellent references:
#   https://mywiki.wooledge.org/BashFAQ/061 (http://archive.fo/sGtzb)
#   https://misc.flogisoft.com/bash/tip_colors_and_formatting (http://archive.fo/NmIkP)
#   https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/ (http://archive.fo/fktxC)
#   https://github.com/webpro/awesome-dotfiles (http://archive.fo/WuiJW)
#   https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
#   https://www.tldp.org/LDP/abs/html/string-manipulation.html
#
# TODO: change all `true` and `false` "boolean" variables to be the full path
#       to the programs.  `true` implies a $PATH search whereas `/bin/true` does not.

# If not running interactively, do not do anything
case "$-" in
    *i*)
        ;;
    *)
        return
        ;;
esac

set -u

# prints an error message when the shift count exceeds the number of positional parameters
shopt -s shift_verbose

# ------------------------------
# important helper `__installed`
# ------------------------------

# XXX: overwrites function in .bash_profile
function __installed () {
    if ! which which &> /dev/null; then
        echo "WARNING: which was not found in current path. This will limit features from this '${0}'" >&2
        echo "         Current Path:" >&2
        echo "         ${PATH}" >&2
        return 1
    fi
    # are all passed args found in the $PATH?
    declare prog=
    for prog in "${@}"; do
        if ! which "${prog}" &>/dev/null; then
            return 1
        fi
    done
}


# ---------------------------------------
# functions for sourcing other bash files
# ---------------------------------------

declare -a __processed_files
__processed_files=()

function __path_dir_bashrc_ () {
    # do not assume this is run from path $HOME. This allows sourcing companion .bash_profile and
    # .bashrc from different paths.
    declare path=${BASH_SOURCE:-}/..
    if __installed dirname; then
        path=$(dirname -- "${BASH_SOURCE:-}")
    fi
    if ! [[ -d "${path}" ]]; then
        path=~  # in case something is wrong, fallback to ~
    fi
    echo -n "${path}"
}

declare __path_dir_bashrc
__path_dir_bashrc=$(__path_dir_bashrc_)
if ! [[ -d "${__path_dir_bashrc}" ]]; then
    __path_dir_bashrc=~
fi

# function readlink_ *should* be defined in companion .bash_profile. But in case was not defined,
# create a stub fallback function
if ! type -t readlink_ &>/dev/null; then
    function readlink_ () {
        echo -n "${1}"
    }
fi

# .bash_profile may have already created $__sourced_files, only create if not already created
if ! [[ "${__sourced_files+x}" ]]; then
    declare -a __sourced_files=()
fi
__sourced_files[${#__sourced_files[@]}]=$(readlink_ "${BASH_SOURCE:-}")  # note this file!

function __source_file_bashrc () {
    declare sourcef=$(readlink_ "${1}")
    if [[ ! -f "${sourcef}" ]]; then
       return
    fi
    if [[ ! -r "${sourcef}" ]]; then
        return 1  # file exists but is not readable
    fi
    echo "${PS4:-}source ${sourcef} from ${BASH_SOURCE:-}" >&2
    __sourced_files[${#__sourced_files[@]}]=${sourcef}
    source "${sourcef}"
}

# .bashrc.local for host-specific customizations to run before the remainder of this .bashrc
__source_file_bashrc "${__path_dir_bashrc}/.bashrc.local.pre"

__PATH_original=${PATH}

# ==============
# PATH additions
# ==============

# add PATHs sooner so calls to `__installed` will search *all* paths the user
# has specified

function __path_add () {
    # append path $1 to $PATH but only if it is
    # - valid executable directory
    # - not already in $PATH

    declare -r path=${1}
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
__path_add "${HOME}/bin"

function __path_add_from_file () {
    # attempt to add paths found in the file $1, assuming a path per-line
    declare path=
    declare -r paths_file=${1}
    if [[ -r "${paths_file}" ]]; then
        __processed_files[${#__processed_files[@]}]=$(readlink_ "${paths_file}")
        while read -r path; do
            __path_add "${path}"
        done < "${paths_file}"
    else
        return 1
    fi
}
__path_add_from_file "${__path_dir_bashrc}/.bash_paths"

# -------------------------------------------------
# search for some important installed programs once
# -------------------------------------------------

# TODO: how to implement this without itself doing path searches?
#       ('true' and 'false' are programs in the path)
#       oddly, running `true` is 1/10 time of running `/bin/true`.   Why is that?

#declare -gA __installed_tracker_array=()
#
#function __installed_tracker () {
#     # search for a program once
#     # further calls will only do an array lookup instead of searching the filesystem.
#     # in theory, this should be faster.

#     declare -i ret=0  # return code
#     declare prog=
#     for prog in "${@}"; do
#         # check if program has been searched already
#         # note if it is not installed
#         if [[ "${__installed_tracker_array[${prog}+x]}" ]]; then
#             # program has been searched, what was the result?
#             if ! ${__installed_tracker_array[${prog}]}; then
#                 ret=1
#             fi
#             continue
#         fi
#         # if a program in $@ was not installed then return failure
#         #if [[ ${ret} -ne 0 ]]; then
#         #    return 1
#         #fi
#         if __installed "${prog}" &>/dev/null; then
#             __installed_tracker_array["${prog}"]=true
#         else
#             __installed_tracker_array["${prog}"]=false
#             ret=1
#         fi
#     done
#     return ${ret}
# }
#__installed_tracker grep sed tr cut

# search once for programs that are used per-prompting
declare -g __installed_grep=false
if __installed grep; then
    __installed_grep=true
fi

declare -g __installed_tr=false
if __installed tr; then
    __installed_tr=true
fi

declare -g __installed_cut=false
if __installed cut; then
    __installed_cut=true
fi

declare -g __installed_column=false
if __installed column; then
    __installed_column=true
fi


# ============================
# other misc. helper functions
# ============================

# note Bash Version
# XXX: presumes single-character versions within string like 'X.Y.…'
declare -i BASH_VERSION_MAJOR=${BASH_VERSION:0:1}  # e.g. '4' in '4.2.10(1)-release'
declare -i BASH_VERSION_MINOR=${BASH_VERSION:2:1}  # e.g. '2' in '4.2.10(1)-release'
export BASH_VERSION_MAJOR \
       BASH_VERSION_MINOR

function what_OS () {
    # attempt to determine what Unix Operating System this is in
    # tips from http://whatsmyos.com/
    # TODO: Incomplete: MinGW bash, cygwin, OpenBSD
    # TODO: this funciton is a bit of a mess and needs some consistency about
    #       what it is aiming to do.

    declare os='unknown'
    declare os_flavor=''
    if [[ -f /proc/version ]]; then
        os='Linux'
        if [[ -f /etc/os-release ]]; then
            # three examples of /etc/os-release :
            #
            #   PRETTY_NAME="Raspbian GNU/Linux 9 (stretch)"
            #   NAME="Raspbian GNU/Linux"
            #   VERSION_ID="9"
            #   VERSION="9 (stretch)"
            #   ID=raspbian
            #   ID_LIKE=debian
            #   HOME_URL="http://www.raspbian.org/"
            #   SUPPORT_URL="http://www.raspbian.org/RaspbianForums"
            #   BUG_REPORT_URL="http://www.raspbian.org/RaspbianBugs"
            #
            #   NAME="Alpine Linux"
            #   ID=alpine
            #   VERSION_ID=3.10.0
            #   PRETTY_NAME="Alpine Linux v3.10"
            #   HOME_URL="https://alpinelinux.org/"
            #   BUG_REPORT_URL="https://bugs.alpinelinux.org/"
            #
            #   NAME="Ubuntu"
            #   VERSION="18.04.3 LTS (Bionic Beaver)"
            #   ID=ubuntu
            #   ID_LIKE=debian
            #   PRETTY_NAME="Ubuntu 18.04.3 LTS"
            #   VERSION_ID="18.04"
            #   HOME_URL="https://www.ubuntu.com/"
            #   SUPPORT_URL="https://help.ubuntu.com/"
            #   BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
            #   PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
            #   VERSION_CODENAME=bionic
            #   UBUNTU_CODENAME=bionic
            #
            (
                eval $(cat /etc/os-release)
                echo -n "${PRETTY_NAME:-${NAME}}"
            )
            return
        elif [[ -f /etc/redhat-release ]]; then
             os_flavor='Redhat '
        fi
        echo -n "${os_flavor}${os}"
        return
    fi

    os='Unix'
    declare sysctl_output
    if sysctl_output=$(sysctl -n kern.osrelease kern.ostype 2>/dev/null); then
        os_flavor='BSD '
        if [[ "${sysctl_output}" = 'FreeBSD' ]]; then
            os_flavor='FreeBSD '
        fi
        echo -n "${os_flavor}${os}"
    fi

    if __installed showrev; then
        os_flavor='Solaris '
    fi
    echo -n "${os_flavor}${os}"
}
__OperatingSystem=$(what_OS)

function __replace_str () {
    # Given string $1, replace substring $2 with string $3 then echo the result.
    #
    # This function is the most portable method for doing such. Programs like `sed` and `awk`
    # vary too much or may not be available. Often, a bash substring replacement
    # (e.g. `${foo//abc/123}`) suffices but bash 3.2 does not recognize '\t' as tab character.
    #
    # tested variations on implemention of this with function using command:
    #     $ bash -i -c 'trap times EXIT; table="A  BB  CCC  DDDD"; source .func; for i in {1..10000}; do __replace_str "${table}" "  " " " >/dev/null; done;'
    #

    if [[ ${#} != 3 ]]; then
        return 1
    fi

    # try bash substring replacement because it's faster, make sure it supports replacing in-line
    # tab character
    declare testvar=' '
    # TODO: test this test on Bash 3.2
    if echo -n "${testvar/ /	}" &>/dev/null; then
        # about 10% faster if the substitution is done for a variable and then echoed
        # instead as versus directly echoed (i.e. two statements is faster than one statement)
        testvar=${1//${2}/${3}}
        echo -n "${testvar}"
        return
    fi

    # bash substring replacement failed so use slower fallback
    # Fallback method is about x6 slower than bash substring replacement.

    declare out=''
    declare -ir l1=${#1}  # strlen of $1
    declare -ir l2=${#2}  # strlen of $2
    declare -i at=0  # index current
    declare -i atb=0  # index of beginning of next replacement
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

function line_count () {
    # count '\n' in stdin as parsed by `read` builtin
    # input '' yields "0"
    # input 'a' yields "1"
    # input 'a\n' yields "2"
    # input 'a\nb' yields "2"
    # input 'a\nb\n' yields "2"
    # input 'a\nb\nc' yields "3"
    declare line=
    declare -i count=0
    while read -rs line; do
        let count+=1
    done
    if [[ "${line}" != '' ]]; then
        let count+=1
    fi
    echo -n "${count}"
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
export HISTSIZE=5000
export HISTFILESIZE=400000
export HISTTIMEFORMAT="%Y%m%dT%H%M%S "
# append to the history file, don't overwrite it
shopt -s histappend

# ------------------------
# globbing and completions
# ------------------------

# see https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html

# includes filenames beginning with a ‘.’ in the results of filename expansion. The filenames ‘.’
# and ‘..’ must always be matched explicitly, even if dotglob is set.
shopt -s dotglob
# patterns which fail to match filenames during filename expansion result in an expansion error.
# XXX: prints debugging messages on Debian bash 4.2, leave off
#shopt -s failglob
# the pattern ‘**’ used in a filename expansion context will match all files and zero or more
# directories and subdirectories. If the pattern is followed by a ‘/’, only directories and
# subdirectories match.
shopt -s globstar
# Bash attempts spelling correction on directory names during word completion if the directory name
# initially supplied does not exist.
shopt -s dirspell

# the following *should* be enabled by default, but be certain because they are important
shopt -s promptvars
shopt -s progcomp
shopt -s progcomp_alias
shopt -s complete_fullquote

# ---------------
# misc...
# ---------------

# check the window size after each command and, if necessary, update the values
# of LINES and COLUMNS.
shopt -s checkwinsize

# make `less` more friendly for non-text input files, see lesspipe(1)
if [[ -x /usr/bin/lesspipe ]]; then
    eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"
fi

# =================================
# Localization - prefer en_US.UTF-8
# =================================

# TODO: check available locales, fallback to one found there?

# available locales can be checked via `locale -a`

export LANG=${LANG:-'en_US.UTF-8'}
export LOCALE=${LOCALE:-'UTF-8'}
# see https://unix.stackexchange.com/a/87763/21203
export LC_ALL=${LC_ALL:-'en_US.UTF-8'}

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
    #      color_force=false . ./.bashrc
    # Force color on
    #      color_force=true . ./.bashrc
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

declare __prompt_bullet_default='‣'  # $ ‣ •
# make sure $prompt_bullet is set
if ! [[ "${prompt_bullet+x}" ]]; then
    declare -g prompt_bullet=${__prompt_bullet_default}
fi

# -------------------
# set title of window
# -------------------

# TODO: record prior title, and then replace it when this login shell exits.
#       currently, login to remote bash overwrites the title, but then never replaces it when it
#       completes.
#
# TODO: consider adjusting title when ssh-ing to other places, e.g. "ssh foo@bar ..." then swap back
#       in.
#

# save the current title? https://unix.stackexchange.com/a/28520/21203
__title_set_prev=$(echo -ne '\e[22t' 2>/dev/null)  # BUG: does not work in most environments
__title_set_TTY=$(tty 2>/dev/null || true)  # set this once
__title_set_kernel=${__title_set_kernel:-kernel $(uname -r)}
__title_set_OS=${__title_set_OS:-${__OperatingSystem}}
#__title_set_hostname=$(hostname)
#__title_set_user=${USER:-}
function __title_set () {
    # title will only accept one line of text
    declare ssh_connection=
    if [[ "${SSH_CONNECTION+x}" ]]; then
        ssh_connection=" (via ${SSH_CONNECTION})"
    fi
    echo -en "\033]0;${USER}@$(hostname) using ${SHELL:-SHELL not set} on TTY ${__title_set_TTY} hosted by ${__title_set_OS} running ${__title_set_kernel}${ssh_connection}\007"
}
function __title_reset () {  # can be called called in ./.bash_logout
    # BUG: does not work in most environments
    echo -en '\033]0;'"${__title_set_prev:-}"'\007'
}
__title_set  # call once, no need to call again

# ============================
# assemble per-prompt commands
# ============================

# these various prompt functions that are called per-prompting are
# written to be efficient.  Avoid searching paths or running programs
# that are unnecessary.  Most state is within global variables. Programs
# have related `__install_program` global variables already set to `true`
# or `false`.

# -----------------------
# prompt terminal details
# -----------------------

function __prompt_table_max () {
    # return maximum integer
    # function name is odd so it is less likely to be overwritten
    if [[ ${1} -gt ${2} ]]; then
        echo -n "${1}"
    else
        echo -n "${2}"
    fi
}

function __window_column_count () {
    # safely get the columns wide (if a command fails, $cols will become value 0)
    declare -i cols
    cols=${COLUMNS:-0}
    if [[ ${cols} -le 0 ]]; then
        cols=$(tput cols 2>/dev/null || true)
    fi
    if [[ ${cols} -le 0 ]]; then
        cols=80  # previous attempts failed, fallback to 80
    fi
    echo -n ${cols}
}

__prompt_table_tty=$(tty 2>/dev/null || true)  # set once

__prompt_table_column_default='│'  # ┃ ║ ║ │ │
if ! [[ "${prompt_table_column+x}" ]]; then
    declare -g prompt_table_column=${__prompt_table_column_default}
fi

if ! [[ "${prompt_table_variables+x}" ]]; then
    # TODO: consider adding checks for various python virtualenvs (virtualenv, pipenv, poetry)
    # TODO: consider adding checks for docker environment
    declare -ga prompt_table_variables=(
        'TERM'
        'color_force'
        'DISPLAY'
        'COLORTERM'
        'SHLVL'
        'tty'
        'STY'
        'SSH_TTY'
        'SSH_CONNECTION'
        'TMUX'
        'GPG_AGENT_INFO'
        'SSH_AUTH_SOCK'
        'SSH_AGENT_PID'
        'PYTHON_PIPENV'
        'PYTHON_PIP_VERSION'
        'PYTHON'
        'VIRTUAL_ENV'
    )
fi

if [[ ! "${__prompt_table_separator+x}" ]]; then
    readonly __prompt_table_separator='❚'  # not seen, do not overwrite
fi

declare -g __prompt_table_column_use=false
function __prompt_table_column_support () {
    # make sure `column` is installed and supports the characters used. With old versions of
    # `column` in non-Unicode environments or in a bad locale $LANG setting, the `column` program
    # will error on multi-byte separator characters.
    # call this once
    __prompt_table_column_use=false
    if ${__installed_column} && \
        (
            echo "${prompt_table_column:-}${__prompt_table_separator}" \
            | column -t -s "${__prompt_table_separator}" -c 80
        ) &>/dev/null
    then
        __prompt_table_column_use=true
    fi
}
__prompt_table_column_support

function __prompt_table () {
    # Creates a basic "table" of interesting environment variables.
    # Adds some safety for terminal column width so a narrow terminal does not
    # have a dump of shared table data.
    # This function and functions it calls make efforts to be efficient as it is expected this
    # function is called for every prompting.
    # BUG: prints trailing column lines, but if .bashrc is sourced again then that is fixed

    declare row1=''
    declare row2=''
    declare -r s1=${prompt_table_column}  # visible columns
    declare -r s2=${__prompt_table_separator}  # temporary separator, will not be printed
    declare -r s="${s2}${s1}"

    #declare b=''  # bold on
    #declare bf=''  # bold off
    #if ${__color_prompt}; then
    #    b='\e[1m'
    #    boff='\e[0m'
    #fi

    declare -ir cols=$(__window_column_count)

    declare varn=  # variable name
    declare -i rows_len=0
    for varn in "${prompt_table_variables[@]}"; do
        # if the rows are already too long for the window column width then do not
        # continue appending to them
        # XXX: assumes ${#s2} is 1 (exactly cancels out '  ' substutition that occurs below)
        if [[ ${rows_len} -gt ${cols} ]]; then
            break
        fi
        # append the variable name to row1 and variable value to row2
        if [[ -n "${varn:-}" ]] && [[ "${!varn+x}" ]]; then
            if [[ 'tty' = "${varn}" ]]; then  # special case
                row1+="${varn}${s}"
                row2+="${__prompt_table_tty}${s}"
                rows_len+=$(($(__prompt_table_max ${#varn} ${#__prompt_table_tty}) + ${#s1}))
            else
                row1+="${varn}${s}"
                row2+="${!varn}${s}"
                rows_len+=$(($(__prompt_table_max ${#varn} $(expr length "${!varn}")) + ${#s1}))
            fi
        fi
    done

    # remove trailing column lines, can only be done in Bash versions >= 4
    if [[ ${#row1} -gt $((${#s}+1)) ]] && [[ ${BASH_VERSION_MAJOR} -ge 4 ]]; then
        row1=${row1::-${#s}}
    fi
    if [[ ${#row2} -gt $((${#s}+1)) ]] && [[ ${BASH_VERSION_MAJOR} -ge 4 ]]; then
        row2=${row2::-${#s}}
    fi
    # avoid printing anything if there is nothing to interesting
    if [[ ${#row1} -eq 0 ]] && [[ ${#row2} -eq 0 ]]; then
        return 0
    fi

    # make attempt to print table-like output based on available programs
    # NOTE: program `column` errors when piped as in `printf '%s\n%s' ... | column ...`. Use `echo`.
    # TODO: consider adding color to table? this would need to be done after substring length
    echo  # start with a newline
    if ${__prompt_table_column_use}; then
        declare table=
        table=$(echo -e "${row1}\n${row2}" | column -t -s "${s2}" -c ${cols})
        table=${table//  ${s1}/${s1}}
        # extract row1 and row2 using "back delete" and "front delete" substring manipulation
        row1=${table%%
*}
        row2=${table##*
}
        echo "${row1::${cols}}"
        echo "${row2::${cols}}"
    else  # print without column alignment; a little ugly
        declare row=
        for row in "${row1}" "${row2}"; do
            if ${__installed_tr}; then
                echo "${row::${cols}}" | tr "${s2}" '\t'
            else
                # no column, no tr; very ugly
                row=${row//${s2}/}
                echo "${row::${cols}}"
            fi
        done
    fi
}

# ---------------
# prompt git info
# ---------------

declare -g __installed_git=false
if __installed git; then
    __installed_git=true
fi

declare -g __installed_stat=false
if __installed stat; then
    __installed_stat=true
fi

# consolidate to one variable
declare -g __prompt_git_info_installed_git_stat=false
if ${__installed_git} && ${__installed_stat}; then  # check once, save result
    __prompt_git_info_installed_git_stat=true
fi

function __prompt_git_info () {
    # a prompt line with git information
    #
    # Most directories are not git repositories so make easy checks try to bail
    # out early before getting to __git_ps1; do not let this function be a drag
    # on the system

    # do the necessary programs exist?
    if ! ${__prompt_git_info_installed_git_stat}; then
        return
    fi

    # does the necessary helper function exist already?
    if ! declare -F __git_ps1 &>/dev/null; then
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

declare __prompt_strftime_format_default='%F %T'
if ! [[ "${prompt_strftime_format+x}" ]]; then
    prompt_strftime_format=${__prompt_strftime_format_default}
fi

function __prompt_set () {
    # set $PS1 with a bunch of good info
    if ${__color_prompt}; then
        declare color_user='32'  # green
        if [[ 'root' = "$(whoami 2>/dev/null)" ]]; then
            color_user='31'  # red
        fi
        # BUG: not putting the $(__prompt_table) on it's own line causes oddity when resizing a window to be smaller;
        #      the next line becomes "attached" to the $(__prompt_table) line.
        #      However, if $(__prompt_table) is given it's own line then when $prompt_table_variables becomes unset there
        #      will be an empty line.
        PS1='
\D{'"${prompt_strftime_format}"'} (last command ${__prompt_timer_show}s; $(__prompt_last_exit_code_show))\[\e[0m\]\[\e[36m\]$(__prompt_table)\[\e[32m\]$(__prompt_git_info)\[\e[0m\]${debian_chroot:+(${debian_chroot:-})}
\[\033[01;'"${color_user}"'m\]\u\[\033[039m\]@\[\033[01;36m\]\h\[\033[00m\]:\[\033[01;34m\]\w
'"${prompt_bullet}"'\[\033[00m\] '
    else
        PS1='
\D{'"${prompt_strftime_format}"'} (last command ${__prompt_timer_show}s; $(__prompt_last_exit_code_show))$(__prompt_table) $(__prompt_git_info)${debian_chroot:+(${debian_chroot:-})}
\u@\h:\w
'"${prompt_bullet}"' '
    fi
}
__prompt_set

function __prompt_live_updates () {
    # special "live" updates that monitor special variables

    declare call_eval_color=false
    declare call___prompt_set=false
    declare call___prompt_table_column_support=false

    # update if necessary
    if [[ "${color_force+x}" ]] && [[ "${__color_force_last:-}" != "${color_force:-}" ]]; then
        call_eval_color=true
        call___prompt_set=true
    fi
    declare -g __color_force_last=${color_force:-}

    # if `unset prompt_table_column` occurred then reset to default
    if ! [[ "${prompt_table_column+x}" ]]; then
        prompt_table_column=${__prompt_table_column_default}
    fi
    # update if necessary
    if [[ "${__prompt_table_column_last:-}" != "${prompt_table_column}" ]]; then
        call___prompt_set=true
        call___prompt_table_column_support=true
    fi
    declare -g __prompt_table_column_last=${prompt_table_column}

    # if `unset prompt_strftime_format` occurred then reset to default
    if ! [[ "${prompt_strftime_format+x}" ]]; then
        prompt_strftime_format=${__prompt_strftime_format_default}
    fi
    # update if necessary
    if [[ "${__prompt_strftime_format_last:-}" != "${prompt_strftime_format}" ]]; then
        call___prompt_set=true
    fi
    declare -g __prompt_strftime_format_last=${prompt_strftime_format}

    # if `unset prompt_bullet` occurred then reset to default
    if ! [[ "${prompt_bullet+x}" ]]; then
        prompt_bullet=${__prompt_bullet_default}
    fi
    # update if necessary
    if [[ "${__prompt_bullet_last:-}" != "${prompt_bullet}" ]]; then
        call___prompt_set=true
    fi
    declare -g __prompt_bullet_last=${prompt_bullet}

    if ${call_eval_color}; then
        eval_color
    fi
    if ${call___prompt_set}; then
        __prompt_set
    fi
    if ${call___prompt_table_column_support}; then
        __prompt_table_column_support
    fi
}

# order is important; additional commands must between functions __prompt_last_exit_code_update and
# __prompt_timer_stop
PROMPT_COMMAND='__prompt_last_exit_code_update; __prompt_live_updates; __prompt_timer_stop'

# ----------
# misc color
# ----------

if (__installed gcc || __installed 'g++') && ${__color_apps}; then
    # colored GCC warnings and errors
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
fi

# =======
# aliases
# =======

function __alias_safely () {
    # create alias if it does not obscure a program in the $PATH
    if type "${1}" &>/dev/null; then
        return 1
    fi
    alias "${1}"="${2}"
}

function __alias_check () {
    # create alias if running the alias succeeds
    (cd ~ && (${2})) &>/dev/null || return
    alias "${1}"="${2}"
}

function __alias_safely_check () {
    # create alias if it does not obscure a program in the $PATH and running the alias succeeds
    if type "${1}" &>/dev/null; then
        return 1
    fi
    if (set -o pipefail; cd ~ && (${2})) &>/dev/null; then
        alias "${1}"="${2}"
    else
        return 1
    fi
}

# -------------
# color aliases
# -------------

# enable color support of ls and also add handy aliases
if ${__color_apps} && [[ -x /usr/bin/dircolors ]]; then
    if [[ -r "${__path_dir_bashrc}/.dircolors" ]]; then
        eval "$(/usr/bin/dircolors -b "${__path_dir_bashrc}/.dircolors")"
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

function __alias_greps_color () {
    # alias various forms of `grep` programs for `--color=auto`

    declare grep_path=
    if ! ${__color_apps}; then
        return 0
    fi
    # various grep interfaces found on Ubuntu 18
    # since each grep will be run, for stability, confine search to /usr/bin and /bin
    for grep_path in \
    /usr/bin/{bzgrep,dgrep,grep,egrep,fgrep,xzgrep,zegrep,zfgrep,zgrep,zipgrep} \
    /bin/{bzgrep,dgrep,grep,egrep,fgrep,xzgrep,zegrep,zfgrep,zgrep,zipgrep}
    do
    declare grep_base=
    grep_base=${grep_path##*/}  # get basename
    # run simplest match with the grep program to make sure it understands option '--color=auto'
    if __installed "${grep_path}" \
        && [[ "$(which "${grep_base}" 2>/dev/null)" = "${grep_path}" ]] \
        && (echo '' | "${grep_path}" --color=auto '' &>/dev/null); then
        alias "${grep_base}"="${grep_path} --color=auto"
    fi
    done
}
__alias_greps_color

# -------------
# other aliases
# -------------

__alias_safely_check l 'ls -lAa'
__alias_safely_check ll 'ls -lAa'
__alias_safely_check la 'ls -Aa'
__alias_safely_check ltr 'ls -Altr'
__alias_safely whence 'type -a'  # where, of a sort
__alias_safely_check psa 'ps -ef --forest'
__alias_safely_check envs env_sorted

if ${__installed_git}; then
    __alias_safely gitb 'git branch -avv'
    __alias_safely gitf 'git fetch -av'
    __alias_safely gits 'git status -vv'
fi

if __installed mount sort column; then
    # TODO: BUG: this fails to be set under Debian 9 WSL
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
        (set -x; wget "${@}" -O "${path}" "${url}")
    elif __installed curl; then
        (set -x; curl "${@}" --output "${path}" "${url}")
    else
        return 1
    fi
}

function __downloader_used () {
    if __installed wget; then
        echo 'wget'
    elif __installed curl; then
        echo 'curl'
    else
        return 1
    fi
}

function __update_dotbashprofile () {
    __download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile' './.bash_profile' "${@}"
}

function __update_dotbashrc () {
    __download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc' './.bashrc' "${@}"
}

function __update_dotvimrc () {
    __download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc' './.vimrc' "${@}"
}

function __update_dotscreenrc () {
    __download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc' './.screenrc' "${@}"
}

function __update_dots () {
    # install other . (dot) files in a one-liner, for fast setup or update of a new linux user shell
    # environment may pass wget/curl parameters to like --no-check-certificate or --insecure
    __update_dotbashprofile "${@}"
    __update_dotbashrc "${@}"
    __update_dotvimrc "${@}"
    __update_dotscreenrc "${@}"
}

# =========================
# source other bashrc files
# =========================

# Do not source ./.bash_profile as that will source ./.bashrc (circular dependency)

# .bashrc.local for host-specific customizations

__source_file_bashrc "${__path_dir_bashrc}/.bashrc.local"
__source_file_bashrc "${__path_dir_bashrc}/.bashrc.local.post"
__source_file_bashrc "${__path_dir_bashrc}/.bash_aliases"

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

    # echo information functions available
    declare funcs=$(__replace_str "$(declare -F)" 'declare -f ' '	')
    declare -i funcs_c=$(echo -n "${funcs}" | line_count)
    echo -e "\
${b}functions (×${funcs_c}) in this shell (declare -F):${boff}

${funcs}
" >&2

    # echo aliases
    declare aliases=$(__replace_str "$(__replace_str "$(alias)" 'alias ' '')" '
' '
	')
    declare -i aliases_c=$(echo -n "${aliases}" | line_count)
    echo -e "\
${b}aliases (×${aliases_c}) in this shell (alias):${boff}

	${aliases}
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
${b}Files Sourced (×${#__sourced_files[@]}):${boff}

$(for src in "${__sourced_files[@]}"; do echo "	${src}"; done)
"

    # echo $__processed_files if any
    if [[ ${#__processed_files[@]} -gt 0 ]]; then
        echo -e "\
${b}Files Processed (×${#__processed_files[@]}):${boff}

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
    declare paths=$(__tab_str "${PATH}" 1 ':')
    declare -i paths_c=$(echo -n "${paths}" | line_count)
    echo -e "\
${b}Paths (×${paths_c}):${boff}

	${paths}
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
		${b}__update_dotbashprofile${boff}  # update ${__path_dir_bashrc}/.bash_profile
		${b}__update_dotbashrc${boff}       # update ${__path_dir_bashrc}/.bashrc
		${b}__update_dotscreenrc${boff}     # update ${__path_dir_bashrc}/.screenrc
		${b}__update_dotvimrc${boff}        # update ${__path_dir_bashrc}/.vimrc
		${b}__update_dots${boff}            # update all of the above
	Parameters like '--no-check-certificate' will be passed to the downloader $(__downloader_used).
	Override color by changing ${b}color_force${boff} to ${b}true${boff} or ${b}false${boff}.
	Change prompt table variables by adding or subtracting from array ${b}prompt_table_variables${boff}. Currently searches for:
		$(__tab_str "$(for i in "${!prompt_table_variables[@]}"; do echo "prompt_table_variables[${i}]=${prompt_table_variables[${i}]}"; let i++; done)" 2)
	Change table column lines by setting ${b}prompt_table_column${boff} (currently '${prompt_table_column}').
	Change PS1 strftime format (prompt date time) by setting ${b}prompt_strftime_format${boff} (currently '${prompt_strftime_format}').
	Override prompt by changing ${b}prompt_bullet${boff} (currently '${b}${prompt_bullet}${boff}').
"
}

infob

set +u
