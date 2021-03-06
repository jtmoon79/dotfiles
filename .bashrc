# .bashrc
#
# A mish-mash of bashrc ideas that are worthwhile, some original ideas, others
# copied. This file is expected to be sourced by it's companion ./.bash_profile
# However, it does support multiple source in the same shell instance.
#
# Works best with companion .bash_profile
#
# Features:
#   - prints context info on startup
#   - prompt prints: timer, return code, datetime,
#     table of variables (adjustable), git prompt line.
#   - attempts to set LOCALE to best choice of UTF-8
#   - allows "live" modification of some prompt features
#   - allows override of various features via ./.bashrc.local.pre, e.g.
#     color, tables of variables, prompt parts, etc.
#   - optional source from ./.bashrc.local.pre, ./.bashrc.local, ./.bashrc.local.post
#   - optional source from ./.bash_paths - per-line paths to add to $PATH
#   - attempts sourcing of /usr/share/bash-completion/bash_completion
#   - fast to install: see companion install.sh at source repository.
#   - fast to update: see __bash_update_bash* functions.
#   - safe to use in many varying Unix environments 🤞 (see docker-tests.sh)
#
# Anti-Features:
#   - not POSIX compliant!
#
# Source at https://github.com/jtmoon79/dotfiles/blob/master/.bashrc
# Install using https://github.com/jtmoon79/dotfiles/blob/master/install.sh
#
# Designed from Debian-derived Linux. Attempts to work with other Linux and Unix
# in varying environments. Avoids reliance on tools like `grep`, `sed`, etc.
# because those tools vary too much or are not available.
#
# (sometimes) tested against
# - bash 4.x on Linux Ubuntu 18
# - bash 4.x on Linux Debian 9
# - bash 4.x on OSX 10
# - bash 3.2 on FreeBSD 10
# - bash docker images within docker-tests.sh
#
# Excellent references:
#   https://tiswww.case.edu/php/chet/bash/bashref.html#index-command (https://archive.vn/mRrbc)
#   https://mywiki.wooledge.org/BashFAQ/061 (http://archive.fo/sGtzb)
#   https://misc.flogisoft.com/bash/tip_colors_and_formatting (http://archive.fo/NmIkP)
#   https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/ (http://archive.fo/fktxC)
#   http://www.solipsys.co.uk/new/BashInitialisationFiles.html (http://archive.ph/CUzSH)
#   https://github.com/webpro/awesome-dotfiles (http://archive.fo/WuiJW)
#   https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
#   https://www.tldp.org/LDP/abs/html/string-manipulation.html
#   http://git.savannah.gnu.org/cgit/bash.git/tree/
#   https://wiki.bash-hackers.org/commands/builtin/printf (http://archive.ph/wip/jDPjC)
#   https://www.shell-tips.com/bash/math-arithmetic-calculation/ (https://archive.vn/dOUw0)
#
# TODO: change all `true` and `false` "boolean" variables to be the full path
#       to the programs.  `true` implies a $PATH search whereas `/bin/true` does
#       not.
#       UPDATE: yet `/bin/true` is many times slower than `true`. Why is that?
#
#               $ time (for i in {0..100}; do true; done)
#               0.002s
#
#               $ time (for i in {0..100}; do /bin/true; done)
#               0.162s
#
#       UPDATE: `true` is a bash built-in, just not well documented. From
#               `man bash`, the clue is this sentence:
#
#                   The :, true, false, and test builtins do not accept options
#                   and do not treat -- specially
#
#                Otherwise, `true` and `false` have no man page entry.
#                Also:
#
#                   $ command -V true
#                   true is a shell builtin
#
#                   $ time (for i in {0..100}; do $(which true); done)
#                   2.602s
#
# TODO: add jobs to prompt when jobs are present. Should behave like git prompt; not visible when no jobs.
#
# TODO: allow more selection of colors for various parts of the prompt
#       e.g $color_prompt_user $color_prompt_table $color_prompt_hostname $color_prompt_path
#           $color_prompt_table_row1 $color_prompt_table_row2 $color_prompt_table_cell_err
#
# TODO: prepend all variables that affect this .bashrc and .bash_profile with a string,
#       e.g. `_bi_` for "bash init"
#
# XXX: bash <4.2 cannot declare empty arrays via "empty array" syntax
#
#          $ array=()
#
#      bash <4.2 interprets that as a subshell invocation.
#      To be backward-compatible, arrays are declared like
#
#          $ array[0]=
#          $ unset array[0]
#
# XXX: `declare -g` is not recognized by bash <=4.1.
#
# XXX: there would be more readonly variables but that causes difficulties
#      if this .bashrc is read for an additional time. Declaring an already
#      existing `readonly` variable is an error. Some tedium is necessary to do
#      so without an error. This file refrains from use of `readonly`.
#
# TODO: add flock to only allow one startup of .bashrc at a time
#       prevents rare case of multiple bash windows using the same tty
#       which can happen when launching `terminator`
#
# TODO: need to allow easy update of .bashrc.local.post without clobbering prior.
#       Consider a __merge_file that is wrapped by a download then merge of temp
#       .bashrc.local.post into ./.bashrc.local.post
#       That would then allow moving that separating particualr settings in this
#       .bashrc (aliases, prompt variables, etc.) into a .bashrc.local.post.
#
# TODO: would a "last prompt" timer be worthwhile? Or too much clutter?
#
# BUG: prompt timer will be 0 if a command is run in a subshell, e.g.
#
#          $ (sleep 3)
#
#      results in next prompt with:
#
#          ... last command 0s ...
#
# TODO: add color to prompt bullet, change it if user is root
#
# TODO: change prompt bullet if user is root
#
# TODO: consider creating a `help` or similar alias that will dump information and
#       provide extended examples.
#


# If not running interactively, do not do anything
case "$-" in
    *i*)
        ;;
    *)
        if [[ "true" = "${__bashrc_FORCE_INTERACTIVE-}" ]]; then
            echo 'Warning: Forcing Interactive Mode! This is only meant for self-testing.' 1>&2
        else
            return
        fi
        ;;
esac

# function readlink_portable *should* be defined in companion .bash_profile. But in case was not defined,
# create a stub function
if ! type -t readlink_portable &>/dev/null; then
    function readlink_portable () {
        echo -n "${@}"
    }
fi

# protect again initialization files that may source in a loop
__bashrc_initialized_flag="$(readlink_portable "${BASH_SOURCE:-}" 2>/dev/null) (${SHLVL})"
if [[ "${__bashrc_initialized+x}" ]] \
  && [[ "${__bashrc_initialized:-}" = "${__bashrc_initialized_flag}" ]]; then
    echo "Skip duplicate initialization of '${__bashrc_initialized}'" >&2
    return
fi
export __bashrc_initialized=${__bashrc_initialized_flag}

# note Bash Version
declare -i BASH_VERSION_MAJOR=${BASH_VERSINFO[0]}
declare -i BASH_VERSION_MINOR=${BASH_VERSINFO[1]}
export BASH_VERSION_MAJOR \
       BASH_VERSION_MINOR

# prints an error message when the shift count exceeds the number of positional parameters
shopt -s shift_verbose

# ------------------------------
# important helper `__bash_installed`
# ------------------------------

# XXX: overwrites function in .bash_profile
__bash_installed_which_warning=false
__bash_installed_which=false
function __bash_installed () {
    # are all passed args found in the $PATH?

    # check that 'which' exists
    # cache that knowledge for slightly faster future calls to this function
    if ! ${__bash_installed_which} && ! which which &> /dev/null; then
        if ${__bash_installed_which_warning}; then
            return 1
        fi
        # print one warning
        __bash_installed_which_warning=true
        echo "WARNING: 'which' was not found in current \$PATH. This will limit features from this '${0}'" >&2
        echo "         Current Path:" >&2
        echo "         ${PATH}" >&2
        return 1
    fi
    __bash_installed_which=true
    declare prog=
    # XXX: bash 3 wants this one particular array expansion to have fallback value
    for prog in "${@:-}"; do
        if ! which "${prog}" &>/dev/null; then
            return 1
        fi
    done
}

# run once so $__bash_installed_which_warning is properly set
__bash_installed
# other sanity warnings (most likely the PATH is screwed up)
# TODO: replace presumed use of these with bash built-in alternatives
for __bashrc_prog_sanity_check in dirname cat; do
    if ! __bash_installed "${__bashrc_prog_sanity_check}"; then
        echo "WARNING: typical Unix program '${__bashrc_prog_sanity_check}' not found in PATH; this shell will behave poorly" >&2
    fi
done
unset __bashrc_prog_sanity_check

function is_installed () {
    # user-facing function wrapper
    __bash_installed "${@}"
}

# ---------------------------------------
# functions for sourcing other bash files
# ---------------------------------------

# XXX: backward-compatible array declaration
__bash_processed_files[0]=''  # global array
unset __bash_processed_files[0]

function __bashrc_path_dir_bashrc_ () {
    # do not assume this is run from path $HOME. This allows sourcing companion .bash_profile and
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

#__bashrc_path_dir_bashrc=
__bashrc_path_dir_bashrc=$(__bashrc_path_dir_bashrc_)
if ! [[ -d "${__bashrc_path_dir_bashrc}" ]]; then
    __bashrc_path_dir_bashrc=~
fi

# .bash_profile may have already created $__bash_sourced_files, only create if not already created
if ! [[ "${__bash_sourced_files+x}" ]]; then
    declare -a __bash_sourced_files=()
fi
__bash_sourced_files[${#__bash_sourced_files[@]}]=$(readlink_portable "${BASH_SOURCE:-}")  # note this file!

function __bashrc_source_file () {
    # shellcheck disable=SC2155
    declare sourcef=$(readlink_portable "${1}")
    if [[ ! -f "${sourcef}" ]]; then
       return
    fi
    if [[ ! -r "${sourcef}" ]]; then
        return 1  # file exists but is not readable
    fi
    echo "${PS4-}source ${sourcef} from ${BASH_SOURCE:-}" >&2
    __bash_sourced_files[${#__bash_sourced_files[@]}]=${sourcef}
    # shellcheck disable=SC1090
    source "${sourcef}"
}

# .bashrc.local for host-specific customizations to run before the remainder of this .bashrc
__bashrc_source_file "${__bashrc_path_dir_bashrc}/.bashrc.local.pre"

# shellcheck disable=SC2034
__bashrc_PATH_original=${PATH}

# ==============
# PATH additions
# ==============

# add PATHs sooner so calls to `__bash_installed` will search *all* paths the user
# has specified

function __bashrc_path_add () {
    # append path $1 to $PATH but only if it is
    # - valid executable directory
    # - not already in $PATH

    declare -r path=${1}
    if [[ ! -d "${path}" ]] || [[ ! -x "${path}" ]]; then  # must be valid executable directory
        return 1
    fi
    # test if any attempts at primitive matching find a match (substring $path within $PATH?)
    # uses primitive substring matching and avoid =~ operator as the path $1 could have regex
    # significant characters
    #      test front
    #      test back
    #      test middle
    if ! {     [[ "${PATH}" = "${PATH##${path}:}" ]] \
            && [[ "${PATH}" = "${PATH%%:${path}}" ]] \
            && [[ "${PATH}" = "${PATH/:${path}:/}" ]] ;
        }
    then
        return 1
    fi
    echo "${PS4-}${FUNCNAME-__bashrc_path_add} '${path}'" >&2
    export PATH=${PATH}:${path}
}

# XXX: `$HOME` may be undefined in very constrained shells (like rescue shells)
#       but `~` is always defined
__bashrc_path_add "${HOME-~}/bin"

function __bashrc_path_add_from_file () {
    # attempt to add paths found in the file $1, assuming a path per-line
    declare path=
    declare -r paths_file=${1}
    if [[ -r "${paths_file}" ]]; then
        __bash_processed_files[${#__bash_processed_files[@]}]=$(readlink_portable "${paths_file}")
        while read -r path; do
            __bashrc_path_add "${path}"
        done < "${paths_file}"
    else
        return 1
    fi
}

__bashrc_path_add_from_file "${__bashrc_path_dir_bashrc}/.bash_paths"

# -------------------------------------------------
# search for some important installed programs once
# -------------------------------------------------

# TODO: how to implement this without itself doing path searches?
#       ('true' and 'false' are programs in the path)
#       oddly, running `true` is 1/10 time of running `/bin/true`.   Why is that?

#__bashrc_installed_tracker_array=()
#
#function __bashrc_installed_tracker () {
#     # search for a program once
#     # further calls will only do an array lookup instead of searching the filesystem.
#     # in theory, this should be faster.

#     declare -i ret=0  # return code
#     declare prog=
#     for prog in "${@}"; do
#         # check if program has been searched already
#         # note if it is not installed
#         if [[ "${__bashrc_installed_tracker_array[${prog}+x]}" ]]; then
#             # program has been searched, what was the result?
#             if ! ${__bashrc_installed_tracker_array[${prog}]}; then
#                 ret=1
#             fi
#             continue
#         fi
#         # if a program in $@ was not installed then return failure
#         #if [[ ${ret} -ne 0 ]]; then
#         #    return 1
#         #fi
#         if __bash_installed "${prog}" &>/dev/null; then
#             __bashrc_installed_tracker_array["${prog}"]=true
#         else
#             __bashrc_installed_tracker_array["${prog}"]=false
#             ret=1
#         fi
#     done
#     return ${ret}
# }
#__bashrc_installed_tracker grep sed tr cut

# ============================
# other misc. helper functions
# ============================

function bashrc_OS () {
    # print a useful string about this OS
    # See also
    #    http://whatsmyos.com/
    #    https://stackoverflow.com/a/27776822/471376
    #
    # TODO: this function is a bit of a mess and needs some consistency about
    #       what it is aiming to do.
    # TODO: this funciton could use $OSTYPE
    # TODO: not tested adequately on non-Linux

    declare uname_=$(uname -s) 2>/dev/null
    declare os='unknown'
    declare os_flavor=''
    if [[ -e /proc/version ]]; then
        os='Linux'
        if [[ -r /etc/os-release ]]; then
            # five examples of /etc/os-release (can you spot the bug?)
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
            #   NAME="CentOS Linux"
            #   VERSION="7 (Core)"
            #   ID="centos"
            #   ID_LIKE="rhel fedora"
            #   VERSION_ID="7"
            #   PRETTY_NAME="CentOS Linux 7 (Core)"
            #   ANSI_COLOR="0;31"
            #   CPE_NAME="cpe:/o:centos:centos:7"
            #   HOME_URL="https://www.centos.org/"
            #   BUG_REPORT_URL="https://bugs.centos.org/"
            #   CENTOS_MANTISBT_PROJECT="CentOS-7"
            #   CENTOS_MANTISBT_PROJECT_VERSION="7"
            #   REDHAT_SUPPORT_PRODUCT="centos"
            #   REDHAT_SUPPORT_PRODUCT_VERSION="7"
            #
            #   NAME=Fedora Remix for WSL
            #   VERSION="29"
            #   ID=fedoraremixforwsl
            #   ID_LIKE=fedora
            #   VERSION_ID=29
            #   PLATFORM_ID="platform:f29"
            #   PRETTY_NAME="Fedora Remix for WSL"
            #   ANSI_COLOR="0;34"
            #   CPE_NAME="cpe:/o:fedoraproject:fedora:29"
            #   HOME_URL="https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL"
            #   SUPPORT_URL="https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL"
            #   BUG_REPORT_URL="https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/issues"
            #   PRIVACY_POLICY_URL="https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/blob/master/PRIVACY.md"
            #
            (
                set +u
                set -e
                # XXX: potential bug in the Fedora WSL file
                # shellcheck disable=SC2046
                source /etc/os-release 2>/dev/null || exit 1
                echo -n "${PRETTY_NAME-${NAME-} ${VERSION_ID-}}"
            ) && return
        elif [[ -r /etc/centos-release ]]; then
            # file /etc/centos-release from older CentOS
            #
            #    CentOS release 6.7 (Final)
            #
            if is_installed tr; then
                cat /etc/centos-release | tr -d '\n'
            else
                cat /etc/centos-release
            fi
            return
        elif [[ -r /etc/redhat-release ]]; then
             os_flavor='Redhat '
        elif [[ "${uname_}" == CYGWIN* ]]; then
            echo -n "${uname_}"
            return
        elif [[ "${uname_}" == MINGW* ]]; then
            echo -n "MinGW ${uname_}"
            return
        elif [[ "${uname_}" == MSYS* ]]; then
            echo -n "${uname_}"
            return
        elif [[ "${uname_}" == Darwin* ]]; then
            echo -n "Mac ${uname_}"
            return
        fi
        echo -n "${os_flavor}${os}"
        return
    fi

    if [[ "${uname_}" != '' ]]; then
        echo -n "${uname_}"
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
        return
    fi

    if __bash_installed showrev; then
        os_flavor='Solaris '
    fi
    echo -n "${os_flavor}${os}"
}

__bashrc_OperatingSystem=$(bashrc_OS)

function __bashrc_replace_str () {
    # Given string $1, replace substring $2 with string $3 then echo the result.
    #
    # This function is the most portable method for doing such. Programs like
    # `sed` and `awk` vary too much or may not be available. Often, a bash
    # substring replacement
    # (e.g. `${foo//abc/123}`) suffices but bash 3.2 does not recognize '\t' as
    # tab character.
    #
    # tested variations on implemention of this with function using command:
    #     $ bash -i -c 'trap times EXIT; table="A  BB  CCC  DDDD"; source .func; for i in {1..10000}; do __bashrc_replace_str "${table}" "  " " " >/dev/null; done;'
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

function __bashrc_tab_str () {
    # prepend tabs after each newline
    # optional $1 is tab count
    # optional $2 is replacement string
    declare -ri tab_count=${2-1}
    declare -r repl=${3-
}
    __bashrc_replace_str "${1}" "${repl}" "
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
        count+=1
    done
    if [[ "${line}" != '' ]]; then
        count+=1
    fi
    echo -n "${count}"
}

function env_sorted () {
    # Print environment sorted
    # Accounts for newlines within environment values (common in $LS_COLORS)

    if ! __bash_installed env sort tr; then
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
# shellcheck disable=SC2034
__bashrc_env_0_original=$(env_sorted)

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
shopt -s globstar 2>/dev/null  # not always available
# Bash attempts spelling correction on directory names during word completion if the directory name
# initially supplied does not exist.
shopt -s dirspell 2>/dev/null  # not always available

# the following *should* be enabled by default, but be certain because they are important
shopt -s promptvars
shopt -s progcomp
shopt -s progcomp_alias 2>/dev/null  # not always available
shopt -s complete_fullquote 2>/dev/null  # not always available

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

# =====================
# Localization settings
# =====================

# from https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
#
#     When a program looks up locale dependent values, it does this according to the following
#     environment variables, in priority order:
#         LANGUAGE
#         LC_ALL
#         LC_xxx, according to selected locale category: LC_CTYPE, LC_NUMERIC, LC_TIME, LC_COLLATE, LC_MONETARY, LC_MESSAGES, ...
#         LANG
#
# from https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
#     GNU gettext gives preference to LANGUAGE over LC_ALL and LANG for the purpose of message handling
#
# also see https://unix.stackexchange.com/questions/149111/what-should-i-set-my-locale-to-and-what-are-the-implications-of-doing-so/149129#149129
#          https://unix.stackexchange.com/questions/87745/what-does-lc-all-c-do/87763#87763

function locale_get () {
    # get an available locale, preferring $1 if passed, then preferring others
    # for reference, a sampling of `locale -a` output on OpenSUSE 15.1 Linux
    #
    #     C
    #     C.UTF-8
    #     …
    #     en_GB.utf8
    #     en_US.utf8
    #     …
    #     POSIX
    #     …
    #     tt_RU@iqtelif
    #     …
    #     ug_CN
    #     uk_UA
    #     uz_UZ
    #     uz_UZ@cyrillic
    #     uz_UZ.utf8
    #
    # XXX: English-centric

    declare locales=
    if ! __bash_installed locale || ! locales=$(locale -a 2>/dev/null); then
        # a fallback value likely to be valid on constrained systems (i.e. Alpine Linux)
        echo -n 'C.UTF-8'
        return 1
    fi

    # shellcheck disable=SC2120
    if [[ "${1+x}" ]] && [[ "${locales}" =~ ${1} ]]; then
        echo -n "${1}"
        return
    fi
    declare locale=
    for locale in \
        'en_US.utf8' \
        'en_US.UTF-8' \
        'en_GB.utf8' \
        'en_GB.UTF-8' \
        'en_US' \
        'C.UTF-8'
    do
        if [[ "${locales}" =~ ${locale} ]]; then
            echo -n "${locale}"
            return
        fi
    done
    # undesirable fallback: uses ASCII, better than nothing
    echo -n 'POSIX'
}

export LOCALE=${LOCALE-'UTF-8'}
__locale_get=$(locale_get)
export LANG=${LANG-${__locale_get}}
export LC_ALL=${LC_ALL-${__locale_get}}  # see https://unix.stackexchange.com/a/87763/21203
# $LANG affect can be seen with code:
#
#     for locale in $(locale -a); do (export LANG=$locale; echo -en "$locale\t"; date); done
#

if __bash_installed less; then
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

function __bashrc_prompt_color_eval () {
    # set a fancy prompt
    declare __bashrc_color=false
    case "${TERM}" in
        screen)
            __bashrc_color=true
            ;;
        xterm)
            __bashrc_color=true
            ;;
        *color)
            __bashrc_color=true
            ;;
        *)
            case "${COLORTERM-}" in  # if $TERM=xterm then $COLORTERM should be set
                *color*)
                    __bashrc_color=true
                    ;;
            esac
    esac

    # default to no color or escape sequences
    __bashrc_prompt_color=false
    __bashrc_color_apps=false

    if ${__bashrc_color}; then
        if [[ -x /usr/bin/tput ]] && /usr/bin/tput setaf 1 &>/dev/null; then
            # We have color support; assume it's compliant with ECMA-48
            # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
            # a case would tend to support setf rather than setaf.)
            __bashrc_prompt_color=true
            __bashrc_color_apps=true
        elif [[ -x /usr/bin/tput ]] && [[ "${__bashrc_OperatingSystem}" =~ 'FreeBSD' ]]; then
           # tput setaf always fails in FreeBSD 10, just try for color
           # https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=210858
            __bashrc_prompt_color=true
            __bashrc_color_apps=true
        else
            __bashrc_prompt_color=false
            __bashrc_color_apps=false
        fi
    fi

    # if $bash_color_force is defined, then set $__bashrc_prompt_color according to $bash_color_force truth
    # Force color off
    #      bash_color_force=false . ./.bashrc
    # Force color on
    #      bash_color_force=true . ./.bashrc
    # shellcheck disable=SC2154
    if [[ -n "${bash_color_force+x}" ]]; then
        if ${bash_color_force} &>/dev/null; then
            __bashrc_prompt_color=true
            __bashrc_color_apps=true
        else
            __bashrc_prompt_color=false
            __bashrc_color_apps=false
        fi
    fi

}

__bashrc_prompt_color_eval

# -------------
# prompt chroot
# -------------

# set variable identifying the current chroot (used in the prompt below)
if [[ -z "${__bashrc_debian_chroot-}" ]] && [[ -r /etc/debian_chroot ]]; then
    __bashrc_debian_chroot=$(cat /etc/debian_chroot)
fi

# ------------
# prompt timer
# ------------

__bashrc_prompt_timer_epoch=false
function __bashrc_prompt_timer_epoch_set () {
    __bashrc_prompt_timer_epoch=false
    if [[ "${EPOCHREALTIME+x}" ]]; then
        __bashrc_prompt_timer_epoch=true
    fi
}

__bashrc_prompt_timer_epoch_set

# idea from http://archive.fo/SYU2A
# It is important that __bashrc_prompt_timer_stop is the last command in the
# $PROMPT_COMMAND.  If there are other commands after it then those
# will be executed and their execution might cause __bashrc_prompt_timer_start to be
# called again. The setting and unset of __bashrc_prompt_timer_cur is to workaround
# internecine subshells that occur per PROMPT_COMMAND.  Subshells should not be
# spawned in __bashrc_prompt_timer_start or __bashrc_prompt_timer_stop.
function __bashrc_prompt_timer_start () {
    if ${__bashrc_prompt_timer_epoch}; then
        __bashrc_prompt_timer_cur=${__bashrc_prompt_timer_cur:-${EPOCHREALTIME}}
    else
        __bashrc_prompt_timer_cur=${__bashrc_prompt_timer_cur:-${SECONDS:-0}}
    fi
}

__bashrc_prompt_timer_start

function __bashrc_prompt_timer_stop () {
    # get time difference since last call, reset prompt timer
    # use $__bashrc_prompt_timer_show for display, not this function
    #
    # $EPOCHREALTIME is microsecond-precision current Epoch time available in bash 5

    if ${__bashrc_prompt_timer_epoch}; then
        # truncate $EPOCHREALTIME to milliseconds
        declare -i toffset=$(((${EPOCHREALTIME//.} - ${__bashrc_prompt_timer_cur//.}) / 1000))
        # truncate to seconds
        declare -i toffset_sec=$((${toffset} / 1000))
        declare units='ms'
    else
        declare -i toffset=$((${SECONDS:-0} - __bashrc_prompt_timer_cur))
        declare -i toffset_sec=${toffset}
        declare units='s'
    fi

    if [[ ${toffset_sec} -ge 60 ]] || ${__bashrc_prompt_timer_epoch}; then
        # show Hour:Minute:Second breakdown
        declare -i h=$((toffset_sec / 3600))
        declare -i m=$((toffset_sec % 3600 / 60))
        declare m_=
        if [[ ${m} -lt 10 ]]; then
            declare m_='0'
        fi
        declare -i s=$((toffset_sec % 60))
        declare s_=
        if [[ ${s} -lt 10 ]]; then
            declare s_='0'
        fi
        __bashrc_prompt_timer_show="${toffset}${units} (${h}:${m_}${m}:${s_}${s})"
    else
        __bashrc_prompt_timer_show="${toffset}${units}"
    fi

    unset __bashrc_prompt_timer_cur
}

trap '__bashrc_prompt_timer_start' DEBUG

# ---------------------
# prompt last exit code
# ---------------------

function __bashrc_prompt_last_exit_code_update () {
    # this function must run first within
    # $PROMPT_COMMAND or else last exit code will be overwritten
    declare -ir last_exit=$?  # first save this value
    __bashrc_prompt_last_exit_code_banner=
    if [[ ${last_exit} -eq 0 ]]; then
        __bashrc_prompt_last_exit_code_banner="return code ${last_exit}"  # normal
    else  # non-zero exit code
        if ${__bashrc_prompt_color}; then
            __bashrc_prompt_last_exit_code_banner="\001\033[01;31m\002‼ return code ${last_exit}\001\033[00m\002"  # red
        else
            __bashrc_prompt_last_exit_code_banner="‼ return code ${last_exit}"  # prepend
        fi
    fi
}

function __bashrc_prompt_last_exit_code_show () {
    echo -en "${__bashrc_prompt_last_exit_code_banner-}"
}

__bashrc_prompt_bullet_default='‣'  # $ ‣ • →  ► ⮕  ⭢ (global)
# make sure $bash_prompt_bullet is set
if ! [[ "${bash_prompt_bullet+x}" ]]; then
    bash_prompt_bullet=${__bashrc_prompt_bullet_default}
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
__bashrc_title_set_prev=$(echo -ne '\e[22t' 2>/dev/null)  # global BUG: does not work in most environments
__bashrc_title_set_TTY=$(tty 2>/dev/null || true)  # global, set this once
__bashrc_title_set_kernel=${__bashrc_title_set_kernel-kernel $(uname -r)}  # global
__bashrc_title_set_OS=${__bashrc_title_set_OS-${__bashrc_OperatingSystem}}  # global
#__bashrc_title_set_hostname=$(hostname)
#__bashrc_title_set_user=${USER-}

function __bashrc_title_set () {
    # title will only accept one line of text
    declare ssh_connection=
    # shellcheck disable=SC2153
    if [[ "${SSH_CONNECTION+x}" ]]; then
        ssh_connection=" (via ${SSH_CONNECTION})"
    fi
    declare user_=${USER-$(whoami)}  # MinGW bash may not set $USER
    declare host_=${HOSTNAME-$(hostname)}  # some bash may not set $HOSTNAME
    echo -en "\033]0;${user_}@${host_} using ${SHELL-SHELL not set} on TTY ${__bashrc_title_set_TTY} hosted by ${__bashrc_title_set_OS} running ${__bashrc_title_set_kernel}${ssh_connection}\007"
}

function __bashrc_title_reset () {  # can be called called in ./.bash_logout
    # BUG: does not work in most environments
    echo -en '\033]0;'"${__bashrc_title_set_prev-}"'\007'
}

__bashrc_title_set  # call once, no need to call again

# ============================
# assemble per-prompt commands
# ============================

# these various prompt functions that are called per-prompting are
# written to be efficient.  Avoid searching paths or running programs
# that are unnecessary.  Most state is within global variables. Programs
# have related `__install_program` global variables already set to `true`
# or `false`.

__bashrc_prompt_color_user_default='32'  # green
if [[ ! "${__bashrc_prompt_color_user+x}" ]]; then
    __bashrc_prompt_color_user=${__bashrc_prompt_color_user_default}
fi
__bashrc_prompt_color_user_root_default='31'  # red
if [[ ! "${__bashrc_prompt_color_user_root+x}" ]]; then
    __bashrc_prompt_color_user_root=${__bashrc_prompt_color_user_root_default}
fi
__bashrc_prompt_color_dateline_default='37'  # light grey
if [[ ! "${__bashrc_prompt_color_dateline+x}" ]]; then
    __bashrc_prompt_color_dateline=${__bashrc_prompt_color_dateline_default}
fi


# -----------------------
# prompt terminal details
# -----------------------

function __bashrc_prompt_table_max () {
    # return maximum integer
    # function name is odd so it is less likely to be overwritten
    if [[ ${1} -gt ${2} ]]; then
        echo -n "${1}"
    else
        echo -n "${2}"
    fi
}

function __bashrc_window_column_count () {
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

__bashrc_prompt_table_tty=$(tty 2>/dev/null || true)  # global, set once

__bashrc_prompt_table_column_default='│'  # ┃ ║ ║ │ │ (global)
if ! [[ "${bash_prompt_table_column+x}" ]]; then
    bash_prompt_table_column=${__bashrc_prompt_table_column_default}  # global
fi

if ! [[ "${bash_prompt_table_variables+x}" ]]; then
    # XXX: backward-compatible array declaration
    bash_prompt_table_variables[0]=''  # global array
    unset bash_prompt_table_variables[0]
fi

function bash_prompt_table_variable_add () {
    # add variable(s) to $bash_prompt_table_variables, do not add if already present
    declare -i i=0
    declare -i ret=0
    declare found=
    declare arg=
    for arg in "${@}"; do
        found=false
        for i in ${!bash_prompt_table_variables[*]}; do
            # special case of zero size array
            if [[ ${#bash_prompt_table_variables[@]} -eq 0 ]]; then
                bash_prompt_table_variables[0]=${arg}
                break
            fi
            if [[ "${bash_prompt_table_variables[${i}]}" == "${arg}" ]]; then
                found=true
                break
            fi
        done
        if ! ${found}; then
            declare -i j=
            # append variable to end of array
            for j in ${!bash_prompt_table_variables[*]}; do
                continue
            done
            j+=1
            bash_prompt_table_variables[${j}]=${arg}
        else  # return 1 if any variable was already present
            ret=1
        fi
    done
    return ${ret}
}

function bash_prompt_table_variable_rm () {
    # remove a variable(s) from the $bash_prompt_table_variables
    declare -i i=0
    declare -i ret=0
    declare found=
    declare arg=
    for arg in "${@}"; do
        found=false
        for i in ${!bash_prompt_table_variables[*]}; do
            if [[ "${bash_prompt_table_variables[${i}]}" == "${arg}" ]]; then
                unset bash_prompt_table_variables[${i}]
                found=true
                break
            fi
        done
        # return 1 if any variable was not found
        if ! ${found}; then
            ret=1
        fi
    done
    return ${ret}
}

function bash_prompt_table_variable_print () {
    # print $bash_prompt_table_variables, optional $2 is tab indent amount
    __bashrc_tab_str "$(
        for i in "${!bash_prompt_table_variables[@]}"; do
            echo "bash_prompt_table_variables[${i}]=${bash_prompt_table_variables[${i}]}"
            let i++
        done
        )" ${1-0}
}

# preload the table with some common shell environment variables that are good to know
bash_prompt_table_variable_add 'TERM'
bash_prompt_table_variable_add 'bash_color_force'
bash_prompt_table_variable_add 'DISPLAY'
bash_prompt_table_variable_add 'COLORTERM'
bash_prompt_table_variable_add 'SHLVL'
bash_prompt_table_variable_add 'STY'
bash_prompt_table_variable_add 'SSH_TTY'
#bash_prompt_table_variable_add 'SSH_CONNECTION'
bash_prompt_table_variable_add 'GPG_AGENT_INFO'
bash_prompt_table_variable_add 'SSH_AUTH_SOCK'
bash_prompt_table_variable_add 'SSH_AGENT_PID'
bash_prompt_table_variable_add 'SSH_ASKPASS'

# ordinal and character copied from https://unix.stackexchange.com/a/92448/21203
function ordinal () {
    # pass a single-character string, prints the numeric ordinal value
    (LC_CTYPE=C printf '%d' "'${1:0:1}")
}

function character () {
    # pass a number, prints the character
    [ "${1}" -lt 256 ] || return 1
    printf "\\$(printf '%03o' "${1}")"
}

function __bashrc_prompt_table_expr_length () {
    # XXX: workaround for getting string length from `${#!var}`. Normally would
    #      use `${#!var}` or `expr length "${!var}"`.
    #      Bash 4.x does not support `${#!var}`
    #      Bash 3.x does not support `expr length ...` operation.
    echo -n "${#1}"
}

# XXX: the following `__bashrc_prompt_table_blank_n_` are various implementations of
#      such. Only one is used but others remain for sake of comparison.

function __bashrc_prompt_table_blank_n_printf1 () {
    # copied from https://stackoverflow.com/a/22048085/471376
    # XXX: presumes `seq`
    #printf '%0.s ' {1..${1}}  # does not correctly expand
    # shellcheck disable=SC2046
    printf '%0.s ' $(seq 1 ${1})
}

function __bashrc_prompt_table_blank_n_printf2 () {
    # copied from https://stackoverflow.com/a/5801221/471376
    printf "%${1}s" ' '
}

function __bashrc_prompt_table_blank_n_for_echo () {
    # copied from https://stackoverflow.com/a/5801221/471376
    declare -i i=0
    for ((; i<${1}; i++)) {
        echo -ne ' '
    }
}

function __bashrc_prompt_table_blank_n_awk () {
    # copied from https://stackoverflow.com/a/23978009/471376
    # XXX: presumes `awk`
    awk "BEGIN { while (c++ < ${1}) printf \" \" ; }"
}

function __bashrc_prompt_table_blank_n_yes_head () {
    # copied from https://stackoverflow.com/a/5799335/471376
    # XXX: `yes` `head` (LOL!)
    echo -n "$(yes ' ' | head -n${1})"
}

function __bashrc_prompt_table_blank_n_head_zero () {
    # copied from https://stackoverflow.com/a/16617155/471376
    # XXX: presumes `head` and `tr`
    head -c ${1} /dev/zero | tr '\0' ' '
}

# XXX: hacky method to quickly print blanks without relying on installed programs
#      or expensive loops
__bashrc_prompt_table_blank_n_buffer='                                                                                                                                                                        '

function __bashrc_prompt_table_blank_n_longstr () {
    echo -ne "${__bashrc_prompt_table_blank_n_buffer:0:${1}}"
}

function __bashrc_prompt_table_blank_n () {
    # wrapper to preferred method
    __bashrc_prompt_table_blank_n_printf2 "${1}"
}

# alias to preferred method
alias __bashrc_prompt_table_blank_n_alias=__bashrc_prompt_table_blank_n_printf2

function __bashrc_prompt_table_blank_n_test_all () {
    declare -ir len=10
    echo "${PS4-} time 1000 iterations of each, length ${len}"

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_printf1 ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_printf1 ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_printf2 ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_printf2 ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_for_echo ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_for_echo ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_awk ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_awk ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_head_zero ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_head_zero ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_longstr ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_longstr ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n ${len}
        done &>/dev/null
    )

    echo -e "\n${PS4-} __bashrc_prompt_table_blank_n_alias ${len}"
    time (
        for i in {1..1000}; do
            __bashrc_prompt_table_blank_n_alias ${len}
        done &>/dev/null
    )
}

function __bashrc_prompt_table () {
    # Creates a basic "table" of interesting environment variables.
    # Typical example:
    #
    #   TERM          │bash_color_force│SHLVL│tty       │SSH_TTY   │LC_ALL    │
    #   xterm-256color│true            │1    │/dev/pts/0│/dev/pts/0│en_US.utf8│
    #
    # Adds some safety for terminal column width so a narrow terminal does not
    # have a dump of shared table data.
    # This function and functions it calls make efforts to be efficient as it is expected this
    # function is called for every prompting.
    #
    # XXX: this function gets slow on low-horsepower hosts. Probably needs some optimization work.

    declare row1=''
    declare row2=''
    declare -r s1=${bash_prompt_table_column}  # visible columns
    #declare b=''  # bold on
    #declare bf=''  # bold off
    #if ${__bashrc_prompt_color}; then
    #    b='\e[1m'
    #    boff='\e[0m'
    #fi
    # shellcheck disable=SC2155
    declare -ir cols=$(__bashrc_window_column_count)
    declare varn=  # variable name
    declare vare=  # $varn evaluated
    declare fs1=  # filler space row 1
    declare fs2=  # filler space row 2
    declare -i v1l=  # varn length
    declare -i v2l=  # vare length
    declare -i rows_len=0  # rows max length
    declare truncate=true
    if [[ "${1:-}" = '--no-truncate' ]]; then
        truncate=false
    fi

    # XXX: it is faster to do this with `tr` and `column` but more portable this way.
    for varn in "${bash_prompt_table_variables[@]}"; do
        # if the rows are already too long for the window column width then do
        # not continue appending to them
        if ${truncate} && [[ ${rows_len} -gt ${cols} ]]; then
            break
        fi

        # skip blank names or undefined values
        if [[ -z "${varn-}" ]] || [[ ! "${!varn+x}" ]]; then
            continue
        fi

        # append the variable name to row1 and variable value to row2
        vare=${!varn}
        v1l=${#varn}
        v2l=${#vare}
        if [[ ${v1l} -gt ${v2l} ]]; then
            fs1=''
            fs2=$(__bashrc_prompt_table_blank_n_alias $((v1l - v2l)))
            rows_len+=${v1l}+${#s1}
        elif [[ ${v1l} -lt ${v2l} ]]; then
            fs1=$(__bashrc_prompt_table_blank_n_alias $((v2l - v1l)))
            fs2=''
            rows_len+=${v2l}+${#s1}
        else
            fs1=''
            fs2=''
            rows_len+=${v1l}+${#s1}
        fi
        row1+="${varn}${fs1}${s1}"
        row2+="${vare}${fs2}${s1}"
    done

    # if there is nothing to print then return
    if [[ ${#row1} -lt ${#s1} ]] && [[ ${#row2} -lt ${#s1} ]]; then
        return 0
    fi

    # make attempt to print table-like output based on available programs
    # TODO: consider adding color to table? this would need to be done after substring length
    if ${truncate}; then
        echo  # start with a newline
        echo "${row1::${cols}}"
        echo "${row2::${cols}}"
    else
        # no newline (presume to *not* be part of the prompt)
        echo "${row1}"
        echo "${row2}"
    fi
}

function bash_prompt_table_print () {
    # Print the *entire* prompt table.
    __bashrc_prompt_table --no-truncate
}

# ---------------
# prompt git info
# ---------------

__bashrc_installed_git=false  # global
if __bash_installed git; then
    __bashrc_installed_git=true
fi

__bashrc_installed_stat=false  # global
if __bash_installed stat; then
    __bashrc_installed_stat=true
fi

# check `stat` works as expected as it can vary among Unixes
# consolidate checks to one variable
__bashrc_prompt_git_info_git_stat=false  # global
if ${__bashrc_installed_git} \
   && ${__bashrc_installed_stat} \
   && [[ "$(stat '--format=%m' --dereference '/' 2>/dev/null)" = '/' ]]; then
    __bashrc_prompt_git_info_git_stat=true
fi

# check `__git_ps1` exists
__bashrc_prompt_git_info_git_ps1=false
if declare -F __git_ps1 &>/dev/null; then
    __bashrc_prompt_git_info_git_ps1=true
fi

function __bashrc_prompt_git_info_do () {
    # should this attempt to run `__git_ps1` helper and make it part of the prompt?
    # do the necessary programs exist?
    # does the necessary helper function `__git_ps1` exist?
    ${__bashrc_prompt_git_info_git_stat} && ${__bashrc_prompt_git_info_git_ps1}
}

function __bash_path_mount_point () {
    # for the path $1, print the mount point
    if ! ${__bashrc_installed_stat}; then
        return 1
    fi
    stat '--format=%m' --dereference "${1}" 2>/dev/null
}

# allow forcing git prompt for mount paths that might be ignored (i.e. some remote paths)
# XXX: backward-compatible global array declaration
__bashrc_prompt_git_info_mountpoint_array[0]=
unset __bashrc_prompt_git_info_mountpoint_array[0]

function __bashrc_prompt_git_info_mountpoint_array_add () {
    # add path to list of paths that should force git prompt
    declare -i ret=0
    declare arg=
    for arg in "${@}"; do
        declare -i len_array=${#__bashrc_prompt_git_info_mountpoint_array[@]}
        declare arg_mp=
        if ! arg_mp=$(__bash_path_mount_point "${arg}"); then
            echo "ERROR: failed to find mount point for '${arg}'" >&2
            ret=1
            continue
        elif [[ "${arg_mp}" = '' ]]; then
            echo "ERROR: failed to find mount point for '${arg}'" >&2
            ret=1
            continue
        fi
        # check if mount path is in $__bashrc_prompt_git_info_mountpoint_array
        declare -i i=0
        declare already_added=false
        while [[ ${i} -lt ${len_array} ]]; do
            if [[ "${__bashrc_prompt_git_info_mountpoint_array[${i}]}" = "${arg_mp}" ]]; then
                already_added=true
                break
            fi
            i+=1
        done
        if ${already_added}; then
            continue
        fi
        # store the paths mountpoint
        if [[ ${len_array} -eq 0 ]]; then
            __bashrc_prompt_git_info_mountpoint_array[0]=${arg_mp}
        else
            __bashrc_prompt_git_info_mountpoint_array[${len_array}]=${arg_mp}
        fi
        echo "${PS4-}${FUNCNAME-__bashrc_prompt_git_info_mountpoint_array_add} '${arg_mp}'" >&2
    done
    return ${ret}
}
__bashrc_prompt_git_info_mountpoint_array_add "/"  # mount point '/' is very likely not a remote filesystem

function __bashrc_prompt_git_info_mountpoint_array_contains () {
    # is path $1 within $__bashrc_prompt_git_info_mountpoint_array ?
    # if contains return 0
    # else return 1
    declare -i len_array=${#__bashrc_prompt_git_info_mountpoint_array[@]}
    declare arg_mp=
    if ! arg_mp=$(__bash_path_mount_point "${1-}"); then
        continue
    elif [[ "${arg_mp}" = '' ]]; then
        continue
    fi
    declare -i i=0
    while [[ ${i} -lt ${len_array} ]]; do
        if [[ "${__bashrc_prompt_git_info_mountpoint_array[${i}]}" = "${arg_mp}" ]]; then
            return 0  # does contain
        fi
        i+=1
    done
    return 1  # do not contain
}

# one element cache
__bashrc_prompt_git_info_cache_path=${PWD}   # global
__bashrc_prompt_git_info_cache_path_do=      # global
__bashrc_prompt_git_info_cache_mountpoint_array_len=${#__bashrc_prompt_git_info_mountpoint_array[@]}  # global

function __bashrc_prompt_git_info () {
    # a prompt line with git information
    #
    # Most directories are not git repositories so make easy checks try to bail
    # out early before getting to __git_ps1; do not let this function slow down
    # prompt refresh.

    if ! __bashrc_prompt_git_info_do; then
        return 1
    fi

    # before iterating through mountpoints and making calls to `stat`, first
    # check the cached result
    if [[ "${__bashrc_prompt_git_info_cache_path}" = "${PWD}" ]] \
    && [[ "${__bashrc_prompt_git_info_cache_path_do}" != '' ]]; then
        if ! ${__bashrc_prompt_git_info_cache_path_do}; then
            return 1
        fi
    else
        # Iterate thought mountpoints to see if `git worktree` should be called.
        # the idea is `git worktree` is only run for some mount points and most
        # preferrably not for remote mount points. Remote mounts often take a
        # long time for `git worktree list` to finish.
        # The user can add to acceptable paths via
        # `__bashrc_prompt_git_info_mountpoint_array_add "/some/path"`.
        declare mountpoint=
        mountpoint=$(__bash_path_mount_point "${PWD}")
        declare mountpoint_okay=false
        declare mountpoint_=
        for mountpoint_ in "${__bashrc_prompt_git_info_mountpoint_array[@]}"; do
            if [[ "${mountpoint_}" = "${mountpoint}" ]]; then
                mountpoint_okay=true
                break
            fi
        done
        if ! ${mountpoint_okay}; then
            return 1
        fi
    fi

    # is this a git worktree?
    if ! git worktree list &>/dev/null; then
        return 1
    fi
    declare out=
    # presumed to be something near the `__git_ps1` defined in
    # https://github.com/git/git/blob/fb628ab129dc2a29581e05edd886e3dc16a4ac49/contrib/completion/git-prompt.sh
    out+="$(export GIT_PS1_SHOWDIRTYSTATE=1
            export GIT_PS1_SHOWSTASHSTATE=1
            export GIT_PS1_SHOWUPSTREAM=1
            if ${__bashrc_prompt_color}; then
                export GIT_PS1_SHOWCOLORHINTS=1
            fi
           __git_ps1 2>/dev/null)" || true
    #out+="$(git rev-parse --symbolic-full-name HEAD) $()"

    # change to red if repository non-clean; check for literal substring '*='
    if ${__bashrc_prompt_color}; then
        # XXX: adding `# shellcheck disable=SC2076` causes error for shellcheck parsing
        if [[ "${out}" =~ '*=' ]] || [[ "${out}" =~ '*+' ]] || [[ "${out}" =~ '*$=' ]] || [[ "${out}" =~ '*$>' ]]; then
            out='\e[31m'"${out}"'\e[0m'  # red
        elif [[ "${out}" =~ '<)' ]]; then
            out='\e[93m'"${out}"'\e[0m'  # light yellow
        elif [[  "${out}" =~ 'GIT_DIR!' ]]; then
            out='\e[1m\e[95m'"${out}"'\e[0m'  #  bold light magenta
        fi
    fi
    # use echo to interpret color sequences here, PS1 will not attempt to interpret this functions
    # output
    echo -en "\ngit:${out}"
}

#
# assemble the prompt pieces
#

__bashrc_prompt_strftime_format_default='%F %T'  # global
if ! [[ "${bash_prompt_strftime_format+x}" ]]; then
    bash_prompt_strftime_format=${__bashrc_prompt_strftime_format_default}
fi

function __bashrc_prompt_set () {
    # set $PS1 with a bunch of good info

    if ${__bashrc_prompt_color}; then
        declare color_user=${__bashrc_prompt_color_user}
        if [[ 'root' = "$(whoami 2>/dev/null)" ]]; then
            color_user=${__bashrc_prompt_color_user_root}
        fi
        # BUG: not putting the $(__bashrc_prompt_table) on it's own line causes oddity when resizing a window to be smaller;
        #      the next line becomes "attached" to the $(__bashrc_prompt_table) line.
        #      However, if $(__bashrc_prompt_table) is given it's own line then when $bash_prompt_table_variables becomes unset there
        #      will be an empty line.
        PS1='
\e['"${__bashrc_prompt_color_dateline}"'m\D{'"${bash_prompt_strftime_format}"'} (last command ${__bashrc_prompt_timer_show-0}; $(__bashrc_prompt_last_exit_code_show))\[\e[0m\]\[\e[36m\]$(__bashrc_prompt_table)\[\e[32m\]${__bashrc_prompt_git_info_show}\[\e[0m\]${__bashrc_debian_chroot:+(${__bashrc_debian_chroot-})}
\[\033[01;'"${color_user}"'m\]\u\[\033[039m\]@\[\033[01;36m\]\h\[\033[00m\]:\[\033[01;34m\]\w
'"${bash_prompt_bullet}"'\[\033[00m\] '
    else
        PS1='
\D{'"${bash_prompt_strftime_format}"'} (last command ${__bashrc_prompt_timer_show-0}; $(__bashrc_prompt_last_exit_code_show))$(__bashrc_prompt_table)${__bashrc_prompt_git_info_show}${__bashrc_debian_chroot:+(${__bashrc_debian_chroot-})}
\u@\h:\w
'"${bash_prompt_bullet}"' '
    fi
}

__bashrc_prompt_set

# __bashrc_prompt_live_updates variables that must be globals
__bashrc_prompt_color_force_last=        # global
__bashrc_prompt_color_user_last=         # global
__bashrc_prompt_color_user_root_last=    # global
__bashrc_prompt_color_dateline_last=     # global
__bashrc_prompt_table_column_last=       # global
__bashrc_prompt_strftime_format_last=    # global
__bashrc_prompt_bullet_last=             # global

function __bashrc_prompt_live_updates () {
    # special "live" updates that monitor special variables

    declare call___bashrc_prompt_color_eval=false
    declare call___bashrc_prompt_set=false

    # update if necessary
    if [[ "${bash_color_force+x}" ]] && [[ "${__bashrc_prompt_color_force_last-}" != "${bash_color_force-}" ]]; then
        call___bashrc_prompt_color_eval=true
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_color_force_last=${bash_color_force-}  # global

    # if `unset __bashrc_prompt_color_user` occurred then reset to default
    if ! [[ "${__bashrc_prompt_color_user+x}" ]]; then
        __bashrc_prompt_color_user=${__bashrc_prompt_color_user_default}  # global
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_color_user_last-}" != "${__bashrc_prompt_color_user}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_color_user_last=${__bashrc_prompt_color_user}  # global

    # if `unset __bashrc_prompt_color_user_root` occurred then reset to default
    if ! [[ "${__bashrc_prompt_color_user_root+x}" ]]; then
        __bashrc_prompt_color_user_root=${__bashrc_prompt_color_user_root_default}  # global
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_color_user_root_last-}" != "${__bashrc_prompt_color_user_root}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_color_user_root_last=${__bashrc_prompt_color_user_root}  # global

    # if `unset __bashrc_prompt_color_dateline` occurred then reset to default
    if ! [[ "${__bashrc_prompt_color_dateline+x}" ]]; then
        __bashrc_prompt_color_dateline=${__bashrc_prompt_color_dateline_default}  # global
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_color_dateline_last-}" != "${__bashrc_prompt_color_dateline}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_color_dateline_last=${__bashrc_prompt_color_dateline}  # global

    # if `unset bash_prompt_table_column` occurred then reset to default
    if ! [[ "${bash_prompt_table_column+x}" ]]; then
        bash_prompt_table_column=${__bashrc_prompt_table_column_default}  # global
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_table_column_last-}" != "${bash_prompt_table_column}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_table_column_last=${bash_prompt_table_column}  # global

    # if `unset bash_prompt_strftime_format` occurred then reset to default
    if ! [[ "${bash_prompt_strftime_format+x}" ]]; then
        bash_prompt_strftime_format=${__bashrc_prompt_strftime_format_default}
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_strftime_format_last-}" != "${bash_prompt_strftime_format}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_strftime_format_last=${bash_prompt_strftime_format}  # global

    # if `unset bash_prompt_bullet` occurred then reset to default
    if ! [[ "${bash_prompt_bullet+x}" ]]; then
        bash_prompt_bullet=${__bashrc_prompt_bullet_default}
    fi
    # update if necessary
    if [[ "${__bashrc_prompt_bullet_last-}" != "${bash_prompt_bullet}" ]]; then
        call___bashrc_prompt_set=true
    fi
    __bashrc_prompt_bullet_last=${bash_prompt_bullet}  # global

    # update cache for git info
#    echo -e "${PS4-}before
#    __bashrc_prompt_git_info_cache_path '${__bashrc_prompt_git_info_cache_path}'
#    __bashrc_prompt_git_info_cache_path_do '${__bashrc_prompt_git_info_cache_path_do}'
#    __bashrc_prompt_git_info_mountpoint_array [${__bashrc_prompt_git_info_mountpoint_array[*]}]
#    __bashrc_prompt_git_info_cache_mountpoint_array_len ${__bashrc_prompt_git_info_cache_mountpoint_array_len}
#    __bash_path_mount_point (current) '$(__bash_path_mount_point .)'
#" >&2
    if __bashrc_prompt_git_info_do; then
        if [[ ${__bashrc_prompt_git_info_cache_mountpoint_array_len} -ne ${#__bashrc_prompt_git_info_mountpoint_array[@]} ]]; then
            __bashrc_prompt_git_info_cache_path_do=
        fi
        if __bashrc_prompt_git_info_show=$(__bashrc_prompt_git_info); then
            __bashrc_prompt_git_info_cache_path_do=true
        else
            __bashrc_prompt_git_info_cache_path_do=false
        fi
        __bashrc_prompt_git_info_cache_path=${PWD}
        __bashrc_prompt_git_info_cache_mountpoint_array_len=${#__bashrc_prompt_git_info_mountpoint_array[@]}
    fi
#    echo -e "${PS4-}after
#    __bashrc_prompt_git_info_cache_path '${__bashrc_prompt_git_info_cache_path}'
#    __bashrc_prompt_git_info_cache_path_do '${__bashrc_prompt_git_info_cache_path_do}'
#    __bashrc_prompt_git_info_mountpoint_array [${__bashrc_prompt_git_info_mountpoint_array[*]}]
#    __bashrc_prompt_git_info_cache_mountpoint_array_len ${__bashrc_prompt_git_info_cache_mountpoint_array_len}
#    __bash_path_mount_point (current) '$(__bash_path_mount_point .)'
#" >&2

    if ${call___bashrc_prompt_color_eval}; then
        __bashrc_prompt_color_eval
    fi
    if ${call___bashrc_prompt_set}; then
        __bashrc_prompt_set
    fi
}

# do not overwrite prior definition of __bashrc_prompt_extras
if ! type -t __bashrc_prompt_extras &>/dev/null; then
    function __bashrc_prompt_extras () {
        # stub function. Override this function in `.bashrc.local.post`.
        # This function runs on every prompt refresh before the table is printed.
        # Useful for terminals that do not automatically update the window $COLUMNS
        # value and require manual update (on FreeBSD, call `resizewin`).
        true
    }
fi

# order is important; additional commands must between functions __bashrc_prompt_last_exit_code_update and
# __bashrc_prompt_timer_stop
PROMPT_COMMAND='__bashrc_prompt_last_exit_code_update; __bashrc_prompt_live_updates; __bashrc_prompt_extras; __bashrc_prompt_timer_stop'

# ----------
# misc color
# ----------

if (__bash_installed gcc || __bash_installed 'g++') && ${__bashrc_color_apps}; then
    # colored GCC warnings and errors
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
fi

# =======
# aliases
# =======

function __bashrc_alias_safely () {
    # create alias if it does not obscure a program in the $PATH
    if type "${1}" &>/dev/null; then
        return 1
    fi
    alias "${1}"="${2}"
}

function __bashrc_alias_check () {
    # create alias if running the alias succeeds
    (cd ~ && (${2})) &>/dev/null || return
    alias "${1}"="${2}"
}

function __bashrc_alias_safely_check () {
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

function bash_alias_add ()  {
    # user-facing function wrapper
    __bashrc_alias_safely "${@}"
}

# -------------
# color aliases
# -------------

# enable color support of ls and also add handy aliases
if ${__bashrc_color_apps} && [[ -x /usr/bin/dircolors ]]; then
    if [[ -r "${__bashrc_path_dir_bashrc}/.dircolors" ]]; then
        eval "$(/usr/bin/dircolors -b "${__bashrc_path_dir_bashrc}/.dircolors")"
    else
        eval "$(/usr/bin/dircolors -b)"
    fi

    __bashrc_alias_check ls 'ls --color=auto'
    if __bash_installed dir; then
        __bashrc_alias_check dir 'dir --color=auto'
    fi
    if __bash_installed vdir; then
        __bashrc_alias_check vdir 'vdir --color=auto'
    fi
fi

function __bashrc_alias_greps_color () {
    # alias various forms of `grep` programs for `--color=auto`

    declare grep_path=
    if ! ${__bashrc_color_apps}; then
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
        if __bash_installed "${grep_path}" \
            && [[ "$(which "${grep_base}" 2>/dev/null)" = "${grep_path}" ]] \
            && (echo '' | "${grep_path}" --color=auto '' &>/dev/null); then
            alias "${grep_base}"="${grep_path} --color=auto"
        fi
    done
}

__bashrc_alias_greps_color

# -------------
# other aliases
# -------------

# TODO: add CLICOLOR, from FreeBSD `ls`
#
#      -G      Enable colorized output.  This option is equivalent to defining
#             CLICOLOR in the environment.  (See below.)  This functionality
#             can be compiled out by removing the definition of COLORLS.  This
#             option is not defined in IEEE Std 1003.1-2001 (“POSIX.1”).
#
#      CLICOLOR            Use ANSI color sequences to distinguish file types.
#                         See LSCOLORS below.  In addition to the file types
#                         mentioned in the -F option some extra attributes
#                         (setuid bit set, etc.) are also displayed.  The
#                         colorization is dependent on a terminal type with the
#                         proper termcap(5) capabilities.  The default “cons25”
#                         console has the proper capabilities, but to display
#                         the colors in an xterm(1), for example, the TERM
#                         variable must be set to “xterm-color”.  Other
#                         terminal types may require similar adjustments.
#                         Colorization is silently disabled if the output is
#                         not directed to a terminal unless the CLICOLOR_FORCE
#                         variable is defined.
#
#     LSCOLORS            The value of this variable describes what color to
#                         use for which attribute when colors are enabled with
#                         CLICOLOR.  This string is a concatenation of pairs of
#                         the format fb, where f is the foreground color and b
#                         is the background color.

# TODO: all alias creation should be moved into an example .bash_aliases
#       that is part of this repository. They can use functions defined here.

__bashrc_alias_safely_check l 'ls -lAa'
__bashrc_alias_safely_check ll 'ls -lAa'
__bashrc_alias_safely_check la 'ls -Aa'
__bashrc_alias_safely_check ltr 'ls -Altr'
__bashrc_alias_safely whence 'type -a'  # where, of a sort
__bashrc_alias_safely_check psa 'ps -ef --forest'
__bashrc_alias_safely_check envs env_sorted

if ${__bashrc_installed_git}; then
    __bashrc_alias_safely gitb 'git branch -avv'
    __bashrc_alias_safely gitf 'git fetch -av'
    __bashrc_alias_safely gits 'git status -vv'
fi

if __bash_installed mount sort column cut; then
    __bashrc_alias_safely mnt 'mount | sort -k3 | column -t | cut -c -${COLUMNS}'
fi

# ===============
# network helpers
# ===============

function print_dev_IPv4() {
    # given passed NIC, print the first found IPv4 address by scraping from
    # outputs of either `ip` or `ifconfig`
    # TODO: this function should use only bash built-in features

    if ! __bash_installed ip && ! __bash_installed ifconfig; then
        return 1
    fi
    if ! __bash_installed grep tr cut; then
        return 1
    fi

    #
    # example Ubuntu 20.04 ifconfig
    #
    # $ ifconfig eth0
    # eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
    #     inet 172.0.0.1  netmask 255.255.240.0  broadcast 172.0.0.255
    #     inet6 fe80::215:ffff:ffff:ffff  prefixlen 64  scopeid 0x20<link>
    #     ether 00:12:34:56:78:90  txqueuelen 1000  (Ethernet)
    #     RX packets 461503  bytes 460569329 (460.5 MB)
    #     RX errors 0  dropped 0  overruns 0  frame 0
    #     TX packets 137051  bytes 10105497 (10.1 MB)
    #     TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
    #
    # example FreeBSD 11 ifconfig
    #
    # $ ifconfig em0
    # em0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    #         options=b<RXCSUM,TXCSUM,VLAN_MTU>
    #         inet 10.10.10.100 netmask 0xffffff00 broadcast 10.10.10.255
    #         ether 00:12:34:56:78:90
    #         media: Ethernet autoselect (1000baseTX <full-duplex>)
    #         status: active
    #
    # example alpine 3.12 ifconfig
    #
    # $ ifconfig eth0
    # eth0      Link encap:Ethernet  HWaddr 00:12:34:56:78:90
    #           inet addr:192.168.1.2  Bcast:192.168.1.255  Mask:255.255.255.0
    #           inet6 addr: fe80::a00:27ff:ffff:ffff/64 Scope:Link
    #           UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
    #           RX packets:26064149 errors:0 dropped:0 overruns:0 frame:0
    #           TX packets:21446837 errors:0 dropped:0 overruns:0 carrier:0
    #           collisions:0 txqueuelen:1000
    #           RX bytes:22454975297 (20.9 GiB)  TX bytes:22240105824 (20.7 GiB)
    #
    # example Ubuntu 18 ip
    #
    # $ ip addr show dev eth0
    # 5: eth0: <BROADCAST,MULTICAST,UP> mtu 1504 group default qlen 1
    #     link/ether 00:12:34:56:78:90
    #     inet 192.168.1.2/24 brd 192.168.1.255 scope global dynamic
    #        valid_lft 29864sec preferred_lft 29864sec
    #

    declare out_=
    # prefer `ip` as it is more consistent and will replace `ifconfig`
    if __bash_installed ip; then
        out_=$(ip address show dev "${1-}" 2>/dev/null) || return 1
        echo -n "${out_}" \
            | grep -m1 -Ee '[[:space:]]inet[[:space:]]' \
            | tr -s ' ' \
            | cut -f3 -d ' ' \
            | cut -f1 -d '/'
    elif __bash_installed ifconfig; then
        out_=$(ifconfig "${1-}" 2>/dev/null) || return 1
        # most `ifconfig` print a leading ' ' but some print leading '\t' (FreeBSD)
        declare line1=
        line1=$(
            echo -n "${out_}" \
            | grep -m1 -Ee '[[:space:]]inet[[:space:]]' \
            | tr -d '	'
        ) || return 1
        # possible variations:
        #     inet addr:192.168.1.2 Bcast:192.168.1.255 Mask:255.255.255.0
        #     inet 10.10.10.100 netmask 0xffffff00 broadcast 10.10.10.255
        #     inet 172.0.0.1 netmask 255.255.240.0 broadcast 172.0.0.255
        line1=$(echo -n "${line1## }" | tr -s ' ') || return 1
        echo -n "${line1}" \
            | cut -f2 -d ' ' \
            | cut -f1 -d '/' \
            | cut -f2 -d ':'
    fi
}

# ============
# self updater
# ============

function __bashrc_download_from_to () {
    declare -r url=${1}
    shift
    declare -r path=${1}
    shift
    if __bash_installed curl; then
        (set -x; curl "${@}" --output "${path}" "${url}")
    elif __bash_installed wget; then
        (set -x; wget "${@}" -O "${path}" "${url}")
    else
        return 1
    fi
    # TODO: add check that if a prior file existed, this update was necessary.
    #       would require
    #       1. downloading to a temporary directory
    #       2. checksum each file, compare
    #       3. overwrite if different
    #       4. let user know what happened
    #       perhaps quieting output of each downloader
    #       also, how to set file datetime to that in HTTP reply?
    #       also, is it possible to do a HEAD first, check if anything needs to be downloaded?
}

function __bashrc_downloader_used () {
    if __bash_installed curl; then
        echo 'curl'
    elif __bash_installed wget; then
        echo 'wget'
    else
        return 1
    fi
}

function __bashrc_downloader_used_example_argument () {
    if __bash_installed curl; then
        echo '--insecure'
    elif __bash_installed wget; then
        echo '--no-check-certificate'
    else
        return 1
    fi
}

function __bash_update_dotbash_profile () {
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_profile' './.bash_profile' "${@}"
}

function __bash_update_dotbashrc () {
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc' './.bashrc' "${@}"
}

function __bash_update_dotbash_logout () {
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bash_logout' './.bash_logout' "${@}"
}

function __bash_update_dotbashrclocalpost () {
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.bashrc.local.post' './.bashrc.local.post' "${@}"
}

function __bash_update_dotbash () {
    # install bash dot files in a one-liner
    __bash_update_dotbash_profile "${@}" \
        && __bash_update_dotbashrc "${@}" \
        && __bash_update_dotbash_logout "${@}"
}

function __bash_update_dotvimrc () {
    if ! __bash_installed vim; then
        return
    fi
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.vimrc' './.vimrc' "${@}"
}

function __bash_update_dotscreenrc () {
    if ! __bash_installed screen; then
        return
    fi
    __bashrc_download_from_to 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/.screenrc' './.screenrc' "${@}"
}

function __bash_update_dots () {
    # install other . (dot) files in a one-liner, for fast setup or update of a new linux user shell
    # environment may pass wget/curl parameters to like --no-check-certificate or --insecure
    __bash_update_dotbash "${@}"
    __bash_update_dotvimrc "${@}"
    __bash_update_dotscreenrc "${@}"
}

function bash_update_dots () {
    # user-facing function wrapper
    __bash_update_dots "${@}"
}

# =========================
# source other bashrc files
# =========================

# Do not source ./.bash_profile as that will source this ./.bashrc (circular dependency)

# .bashrc.local for host-specific customizations
__bashrc_source_file "${__bashrc_path_dir_bashrc}/.bashrc.local"
__bashrc_source_file "${__bashrc_path_dir_bashrc}/.bash_aliases"
__bashrc_source_file "${__bashrc_path_dir_bashrc}/.bashrc.local.post"

if ! shopt -oq posix; then
    # XXX: other "official" completion files often have variable expansion errors
    set +u
    __bashrc_source_file /usr/share/bash-completion/bash_completion
    __bashrc_source_file /etc/bash_completion
    set -u
fi

# ====================================================
# print information this .bashrc has done for the user
# ====================================================

function bashrc_start_info () {
    # echo information about this shell instance for the user with pretty formatting and indentation

    # TODO: show newly introduced environment variables
    #       But how to diff input from stdin? Creating temporary files to feed to diff is too risky for
    #       a startup script.

    declare b=''
    declare boff=''
    if ${__bashrc_prompt_color}; then
        b='\e[1m'
        boff='\e[0m'
    fi

    function __bashrc_start_info_time_start() {
        # __bash_start_beg_time should be set by calling .bash_profile
        # XXX: a smoother way to do this would be overriding the prompt_timer values
        #      once during startup
        if [[ ! "${__bash_start_beg_time+x}" ]]; then
            return 1
        fi
        __bash_start_end_time=${EPOCHREALTIME-}
        if [[ -n "${__bash_start_end_time}" ]]; then
            echo "Time taken during startup was $(( ( ${__bash_start_end_time//.} - ${__bash_start_beg_time//.} ) / 1000)) milliseconds"
        else
            __bash_start_end_time=${SECONDS}
            echo "Time taken during startup was $((__bash_start_end_time - __bash_start_beg_time)) seconds"
        fi
    }

    if [[ "${1-}" == '--minimal' ]]; then
        echo -e "Run ${b}bashrc_start_info${boff} for detailed information about this shell instance."
        echo -e "Run ${b}bash_update_dots${boff} to update."
        __bashrc_start_info_time_start
        return
    fi

    # echo information about this bash
    echo "\
Using bash ${BASH_VERSION}, process ID $$
"

    # echo information functions available
    declare funcs=$(__bashrc_replace_str "$(declare -F)" 'declare -f ' '	')
    declare -i funcs_c=$(echo -n "${funcs}" | line_count)
    echo -e "\
${b}functions (×${funcs_c}) in this shell (declare -F):${boff}

${funcs}
"

    # echo aliases
    declare aliases=$(__bashrc_replace_str "$(__bashrc_replace_str "$(alias)" 'alias ' '')" '
' '
	')
    declare -i aliases_c=$(echo -n "${aliases}" | line_count)
    echo -e "\
${b}aliases (×${aliases_c}) in this shell (alias):${boff}

	${aliases}
"

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
	LOCALE='${LOCALE-NOT SET}'
	BASH_VERSION_MAJOR='${BASH_VERSION_MAJOR}'
	BASH_VERSION_MINOR='${BASH_VERSION_MINOR}'
	__bashrc_debian_chroot='${__bashrc_debian_chroot-NOT SET}'
	bash_prompt_bullet='${bash_prompt_bullet-NOT SET}'
	bash_color_force=${bash_color_force-NOT SET}
	__bashrc_color=${__bashrc_color-NOT SET}
	__bashrc_prompt_color=${__bashrc_prompt_color-NOT SET}
	__bashrc_color_apps=${__bashrc_color_apps-NOT SET}
	__bashrc_OperatingSystem='${__bashrc_OperatingSystem}'
	__bashrc_env_0_original=… (too large to print)
"

    # echo $__bash_sourced_files
    echo -e "\
${b}Files Sourced (×${#__bash_sourced_files[@]}):${boff}

$(for src in "${__bash_sourced_files[@]}"; do echo "	${src}"; done)
"

    # echo $__bash_processed_files if any
    if [[ ${#__bash_processed_files[@]} -gt 0 ]]; then
        echo -e "\
${b}Files Processed (×${#__bash_processed_files[@]}):${boff}

$(for src in "${__bash_processed_files[@]}"; do echo "	${src}"; done)
"
    fi

    # echo multiplexer server status
    if [[ -n "${TMUX-}" ]] && __bash_installed tmux; then
        echo -e "\
${b}tmux Settings:${boff}

	tmux ID: $(tmux display-message -p '#S')
	tmux sessions:
		$(__bashrc_tab_str "$(tmux list-sessions)" 2)
"
    elif [[ -n "${STY-}" ]] && __bash_installed screen; then
        # shellcheck disable=SC2155
        declare __screen_list=$(screen -list 2>/dev/null)
        if __bash_installed tail; then
            __screen_list=$(echo -n "${__screen_list}" | tail -n +2)
            __screen_list=${__screen_list:1}
        fi
        echo -e "\
${b}screen Settings:${boff}

	screen: $(screen --version)
	screen ID: ${STY}
	screen Sessions:
		$(__bashrc_tab_str "${__screen_list}")
"
    fi

    # echo $PATHs
    declare paths=$(__bashrc_tab_str "${PATH}" 1 ':')
    # shellcheck disable=SC2155
    declare -i paths_c=$(echo -n "${paths}" | line_count)
    echo -e "\
${b}Paths (×${paths_c}):${boff}

	${paths}
"

    # echo information about other users, system uptime
    if __bash_installed w; then
        echo -e "\
${b}System and Users (w):${boff}

	$(__bashrc_tab_str "$(w)")
"
    fi

    # echo special features in a special way
    echo -e "\
${b}Special Features of this .bashrc:${boff}

	Update a dot file by calling one of the functions:
		${b}__bash_update_dotbash_profile${boff}  # update ./.bash_profile
		${b}__bash_update_dotbashrc${boff}        # update ./.bashrc
		${b}__bash_update_dotbash_logout${boff}   # update ./.bash_logout
		${b}__bash_update_dotbash${boff}          # update prior .bash files
		${b}__bash_update_dotbashrclocalpost${boff}  # update ./.bashrc.local.post
		${b}__bash_update_dotscreenrc${boff}      # update ./.screenrc
		${b}__bash_update_dotvimrc${boff}         # update ./.vimrc
		${b}bash_update_dots${boff}               # update all of the above
	Parameters like '$(__bashrc_downloader_used_example_argument)' will be passed to the downloader $(__bashrc_downloader_used).

	Force your preferred multiplexer by setting ${b}force_multiplexer${boff} to 'tmux' or 'screen' in file ~/.bash_profile.local (requires new bash login)
	Can override ${b}__bashrc_prompt_extras${boff} in ${b}.bashrc.local.post${boff}.
	Override color by changing ${b}bash_color_force${boff} to ${b}true${boff} or ${b}false${boff}.
	Change prompt table variables by adding or subtracting from array ${b}bash_prompt_table_variables${boff} using ${b}bash_prompt_table_variable_add${boff} or ${b}bash_prompt_table_variable_rm${boff}.
	${b}bash_prompt_table_variables${boff} currently displays:
		$(bash_prompt_table_variable_print 2)
	Change table column lines by setting ${b}bash_prompt_table_column${boff} (currently '${bash_prompt_table_column}').
	Change PS1 strftime format (prompt date time) by setting ${b}bash_prompt_strftime_format${boff} (currently '${bash_prompt_strftime_format}').
	Override prompt by changing ${b}bash_prompt_bullet${boff} (currently '${b}${bash_prompt_bullet}${boff}').
	$(__bashrc_start_info_time_start)

	Turn off prompt activity with:
		trap '' DEBUG
		PROMPT_COMMAND=
		PS1=
"
}

bashrc_start_info --minimal >&2

set +u
