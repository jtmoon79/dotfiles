#!/usr/bin/env bash
#
# this file is an experiment and can be ignored.

set -e
set -u
set -o pipefail

function __max() {
    if [[ ${1} -gt ${2} ]]; then
        echo -n "${1}"
    else
        echo -n "${2}"
    fi
}

function table()
{
    # Print the input in a table of rows and columns
    # $1 is the column count, remaining arguments are table cells.
    #
    #    table 2 a bb c d
    #
    # prints
    #
    #    ╔═╤══╗
    #    ║a│bb║
    #    ╟─┼──╢
    #    ║c│d ║
    #    ╚═╧══╝
    #
    # Can handle table cells with newlines
    #
    # Table delineators use Unicode characters from DOS Code Page 437 which
    # are the most portable Box-drawing characters.
    #
    # Not efficient‼ There have been many Programming Competition Submissions
    # that have done this better.
    #

    #
    # find reasons to exit early
    #

    if [[ ${#} -lt 1 ]]; then
        return 1
    fi

    declare -ir colc=${1}  # column count
    shift
    if [[ ${colc} -lt 0 ]]; then
      return 1
    elif [[ ${colc} -eq 0 ]] && [[ ${#} -eq 0 ]]; then
      return 0  # nothing to do but not an error
    elif [[ ${colc} -eq 0 ]] && [[ ${#} -gt 0 ]]; then
      return 1
    elif [[ ${colc} -gt ${#} ]]; then
        return 1
    fi

    declare -a data=("${@}")
    # fill in any missing data cells with empty string
    while [[ $(expr ${#data[@]} % ${colc}) -ne 0 ]]; do
        # argumentc count not divisible by column count
        data[${#data[@]}]=''
    done
    declare -r data
    declare -ir rowc=$(expr ${#data[@]} '/' ${colc})  # row count

    #
    # helper functions
    #

    function __newlines() {
        # echo count of newlines in $1
        [[ ${#} -eq 1 ]] || return 1
        declare -r nl='
'
        declare -i nc=0  # newline count
        declare -i i=
        for ((i = 0; i < "${#1}"; ++i)); do
            if [[ "${1:$i:1}" = "${nl}" ]]; then
                let nc++ || true
            fi
        done
        echo -n ${nc}
    }

    __line_str() {
        # $1 string line number, $2 string
        # echo the line at line number within $2
        declare -r nl='
'
        [[ ${#} -eq 2 ]] || return 1
        [[ ${1} -gt -1 ]] || return 1

        declare -ir nc=$(__newlines "${2}")  # newline count, one-indexed
        declare -ir linen=${1}  # string line number, zero-indexed
        if [[ ${linen} -gt $(expr ${nc} + 1) ]]; then
            return
        fi

        # find the start of line at $linen
        declare -i i=0
        declare -i ni=0
        for ((i = 0; i < ${#2}; ++i)); do
            if [[ ${ni} -eq ${linen} ]]; then
                break
            fi
            if [[ "${2:${i}:1}" = "${nl}" ]]; then
                let ni++ || true
            fi
        done

        # $i points to the start of the line at $linen
        declare -ir ls=${i}  # line start
        for ((; i < ${#2}; ++i)); do
            if [[ "${2:${i}:1}" = "${nl}" ]]; then
                break
            fi
        done
        declare -ir ll=$(expr ${i} - ${ls})  # line length

        echo -n "${2:${ls}:${ll}}"
    }

    declare -i r=  # row index
    declare -i c=  # col index
    declare -i i=  # current index
    declare cell=

    #
    # find column widths
    #

    declare -i cw=
    declare -a colw=()  # column max width string length
    for ((c = 0; c < ${colc}; ++c)); do
        declare -i cw=0
        for ((r = 0; r < ${rowc}; ++r)); do
            declare -i i=$(expr '(' ${r} '*' '(' ${colc} ')' ')' + ${c} )
            cell=${data[${i}]}
            declare -i ch=$(__newlines "${data}")
            for ((i = 0; i <= ${ch}; ++i)); do
                declare line
                line=$(__line_str ${i} "${cell}")
                cw=$(__max ${cw} ${#line})
            done
        done
        colw[${c}]=${cw}
    done

    #
    # find row heights
    #

    declare -i rh=
    declare -a rowh=()  # column max width string length
    for ((r = 0; r < ${rowc}; ++r)); do
        declare -i rh=0
        for ((c = 0; c < ${colc}; ++c)); do
            declare -i i=$(expr '(' ${c} '*' '(' ${rowc} ')' ')' + ${r} )
            cell=${data[${i}]}
            rh=$(__max $(expr $(__newlines "${cell}") + 1) ${rh})
        done
        rowh[${r}]=${rh}
    done

    # print table preview
    #for ((r = 0; r < ${rowc}; ++r)); do
    #    for ((c = 0; c < ${colc}; ++c)); do
    #        declare -i i=$(expr '(' ${r} '*' '(' ${colc} ')' ')' + ${c} )
    #        echo -n "$c,$r[$i]"
    #        cell=${data[${i}]}
    #        echo -n " '${cell}' "
    #    done
    #    echo
    #done | column -t
    #echo -e "\nColumns Widths:\n${colw[@]}"
    #echo -e "\nRow Heights:\n$(for a in ${rowh[@]}; do echo $a; done)"

    #
    # print the table
    #

    # print top of table
    declare t=''
    t+='╔'  # top-left-most edge of table
    declare -i cwi=0
    for cw in ${colw[@]}; do
        let cwi++ || true
        for ((c = 0; c < ${cw}; ++c)); do
            t+='═'
        done
        [[ ${cwi} -eq ${#colw[@]} ]] || t+='╤'  # '╦'
    done
    t+='╗
'  # top-right-most edge of table

    # print contents of table
    for ((r = 0; r < ${rowc}; ++r)); do  # row number
        for ((rh = 0; rh < ${rowh[${r}]}; ++rh)); do  # row height (line num)
            t+='║'  # left-most edge of table
            for ((c = 0; c < ${colc}; ++c)); do  # column number
                cw=${colw[${c}]}
                declare -i i=$(expr '(' ${r} '*' '(' ${colc} ')' ')' + ${c} )
                cell=${data[${i}]}  # entire cell data, one or more lines
                cell=$(__line_str ${rh} "${cell}")  # one line of cell data
                t+=${cell}
                for ((i = 0; i < $(expr ${cw} - ${#cell}); ++i)); do
                    t+=' '
                done
                [[ ${c} -eq $(expr ${colc} - 1) ]] || t+='│'  # '║'
            done
            t+='║
'  # at right-most edge of table
        done

        if [[ ${r} -lt $(expr ${rowc} - 1) ]]; then
            # print row-dividing horizontal line
            t+='╟'
            declare -i cwi=0
            for cw in ${colw[@]}; do
                let cwi++ || true
                for ((c = 0; c < ${cw}; ++c)); do
                    t+='─'
                done
                [[ ${cwi} -eq ${#colw[@]} ]] || t+='┼'  # '╫'
            done
            t+='╢
'  # at right-most edge of table
        else
            # print bottom of table
            t+='╚'  # bottom-left-most edge of table
            declare -i cwi=0
            for cw in ${colw[@]}; do
                let cwi++ || true
                for ((c = 0; c < ${cw}; ++c)); do
                    t+='═'
                done
                [[ ${cwi} -eq ${#colw[@]} ]] || t+='╧'  # '╩'
            done
            t+='╝
'  # bottom-right-most edge of table
        fi
    done

    # write table to stdout
    echo -n "${t}"

    return
}

function columnb ()
{
    # column in bash
    # behave like unix program `column`
    # allow passing `-s` for the field delimiter string

    declare fd=' '  # default field delimiter
    # scan for
    #    -t
    #    -s 'x'
    declare do_table=false
    while [[ "${1+x}" ]]; do
        case "${1}" in
            '-t')
                do_table=true
                shift
                ;;
            '-s')
                shift
                if ! [[ "${1+x}" ]]; then
                    echo "ERROR: columnb: no argument passed to -s" >&2
                    return 1
                fi
                fd=${1}
                shift
                ;;
             *)
                echo "ERROR: columnb: passed unexpected argument '${1}'" >&2
                return 1
        esac
    done

    function expr_() {
        # expr returning 0 causes process return code 1 which causes a failure
        # #bashproblems
        expr "${@}" || true
    }

    declare -ir fdl=${#fd}  # field delimiter length
    declare line=
    declare -i lc=0  # line count
    declare -i i=0
    declare -i j=0
    declare -a args=()  # arguments
    declare -a argl=()  # line number of argument, supplements $args
    declare -i wa=0  # widest args per line (i.e. column count)
    while read -r line; do
        i=0
        declare -i acl=1  # arg count this line
        for ((j = 0; j < ${#line}; j+=1)); do
            if [[ "${line:${j}:${fdl}}" = "${fd}" ]]; then
#echo "${PS4}\${line:${i}:\$(expr_ ${j} - ${i})} '${line}'"
                args[${#args[@]}]=${line:${i}:$(expr_ ${j} - ${i})}
                argl[${#argl[@]}]=${lc}
#echo "${PS4}\$(expr_ ${j} + ${fdl})"
                i=$(expr_ ${j} + ${fdl})
                j=${i}
                let acl++ || true
            fi
        done
        wa=$(__max ${wa} ${acl})
        args[${#args[@]}]=${line:${i}:$(expr_ ${j} - ${i})}
        argl[${#argl[@]}]=${lc}
        let lc++ || true
    done
    declare -r args argl wa lc

    #echo "${PS4:-}$(for arg in "${args[@]}"; do echo -n "(${arg}) "; done)" >&2
    #echo "${PS4:-}${argl[@]}" >&2

    if ${do_table}; then
        # fill in gaps in $args with empty strings to create  a dataset table
        # can print correctly,
        # e.g. if $args is intended to be two rows
        #    args=('1a' '2a' '2b' '2c')
        # then $argst becomes
        #    argst=('1a' '' '' '2a' '2b' '2c')
        #
        declare -a argst=()
        declare -i a=0  # track $args
        declare -i k=
        #echo "${PS4} \${argl[@]}:${argl[@]}" >&2
        #echo "${PS4} \${#argl[@]}:${#argl[@]}" >&2
        #echo "${PS4} \${#args[@]}:${#args[@]}" >&2
        for ((k = 0; k < ${lc}; ++k)); do  # for each line/row (zero-indexed)
            for ((i= 0; i < ${wa}; ++i)); do  # for each arg/column (zero-indexed)
                #echo "${PS4} k:${k} i:${i} a:${a} \${#argst[@]}:${#argst[@]}" >&2
                declare val=
                if [[ ${a} -lt ${#argl[@]} ]] && \
                   [[ ${argl[${a}]} -eq ${k} ]]; then
                    val=${args[${a}]}
                    let a+=1 || true
                fi
                argst[${#argst[@]}]=${val}
            done
        done
        #echo "${PS4} a:${a} \${#args[@]}:${#args[@]}" >&2
        #echo "${PS4} table ${wa}" "${argst[@]}" >&2
        table ${wa} "${argst[@]}"
    else
        # print all args, per line they were passed
        for ((i = 0; i < ${#args[@]}; ++i)); do
            echo -n "${args[${i}]}"
            if [[ ${i} -lt $(expr_ ${#args[@]} - 1) ]] && \
               [[ ${argl[${i}]} != ${argl[${i}+1]} ]]; then
                echo
            else
                echo -n ' '
            fi
        done
        echo
    fi
    #echo >&2
}

echo 'GOOD CASES'

set -v
echo | columnb
echo '' | columnb
echo 'a' | columnb
echo 'a b' | columnb
echo 'a  b' | columnb
echo 'a   b' | columnb
echo 'a b c' | columnb
echo 'a bb ccc' | columnb
echo 'a bb ccc dddd' | columnb
echo 'a bb ccc dddd eeeee' | columnb

echo | columnb
echo '
' | columnb
echo 'a
' | columnb
echo 'a
b' | columnb
echo 'a b
c' | columnb
echo 'a bb
ccc' | columnb
echo 'a bb
ccc
dddd eeeee' | columnb
echo 'a
bb
ccc
dddd
eeeee' | columnb
echo 'a bb ccc dddd' | columnb
echo 'a bb ccc dddd eeeee' | columnb

echo '' | columnb -s '_'
echo 'a' | columnb -s '_'
echo 'a_b' | columnb -s '_'
echo 'a_b_c' | columnb -s '_'
echo 'a_bb_ccc' | columnb -s '_'
echo 'a_bb_ccc_dddd' | columnb -s '_'
echo 'a_bb_ccc_dddd_eeeee' | columnb -s '_'

echo '' | columnb -s '+='
echo 'a' | columnb -s '+='
echo 'a+=b' | columnb -s '+='
echo 'a+=b+=c' | columnb -s '+='
echo 'a+=bb+=ccc' | columnb -s '+='
echo 'a+=bb+=ccc+=dddd' | columnb -s '+='
echo 'a+=bb+=ccc+=dddd+=eeeee' | columnb -s '+='

#echo | columnb -t
echo '' | columnb -t || true
echo 'a' | columnb -t
echo 'a b' | columnb -t
echo 'a b c' | columnb -t
echo 'a bb ccc' | columnb -t
echo 'a bb ccc dddd' | columnb -t
echo 'a bb ccc dddd eeeee' | columnb -t

echo '' | columnb -t
echo 'a' | columnb -t
echo 'a b' | columnb -t
echo 'a b c' | columnb -t
echo 'a bb ccc' | columnb -t
echo 'a bb ccc dddd' | columnb -t
echo 'a bb ccc dddd eeeee' | columnb -t
echo 'aaaaa bbbb ccc dd e' | columnb -t
echo 'aaa bbbb ccccc dddd eee' | columnb -t
echo 'aaaaa bbbb ccc dddd eeeee' | columnb -t
echo "\
aaaaa
bbbb
ccc
dddd
eeeee" | columnb -t
echo "\
a
bb
ccc
dd
e" | columnb -t
echo "\
a aa aaa
bb
ccc
dd
e" | columnb -t

echo 'abcdef' | columnb -s '|||'
echo 'aaa|||b' | columnb -s '|||'
echo 'aaa|||b|||c' | columnb -s '|||'
echo 'aaa|||b|||CCCCCC' | columnb -s '|||'

echo 'aaa|||b
|||c' | columnb -s '|||' -t
echo 'a|||bb
|||ccc|||
dddd' | columnb -s '|||' -t

echo 'aaa b
 c' | columnb -t
echo 'a bb
 ccc 
dddd' | columnb -t

if true; then
    echo 'BAD CASES'
    ! (echo | columnb -s)
    echo $?
    ! (echo | columnb -s)
    echo $?
    ! (echo | columnb -s a b)
    echo $?
    ! (echo | columnb a)
    echo $?
fi

time table 0

time table 1 a

time table 1 a b

time table 2 a b

table 2 a b c d

table 2 a b c d e f

table 3 a b c d e f

time table 2 a bb c d

time table 3 a b c  d e f  g h i
time table 3 a b c  d ee f  g h iii
time table 4 aa b c d  ee f g h  i j kkk l

time time table 3 'a
a' b c d e f

time table 3 'a
aa
aaa' b c d e FFF

time table 3 \
'COLUMN 1' '#2' 'COL 3' \
''

time table 3 \
'COLUMN 1' '#2'   'COL 3' \
'foobar'   'two'  '333' \
'blarg'    'too'  'thr
ee' \
'blumpf'   'to'   'thrice' \
'drang!'   '²'    '1+1+1' \
'¿'        '₂'    '
' \
'⁇'         '๒'   ' ¾
+¾
+¾
+¾
⏤
 3' \

echo \
'COLUMN 1|#2 COL|3
foobar|two|333
blarg|too|thr
ee
blumpf|to|thrice
drang!|²|1+1+1
¿|₂| 
⁇|๒| ¾+¾+¾+¾
⏤⏤⏤⏤⏤⏤⏤⏤|⏤⏤⏤⏤⏤⏤|⏤⏤⏤⏤⏤⏤⏤⏤
 | |3' \
    | columnb -s '|' -t

if false; then
echo 'BAD CASES'
! (table)
echo $?
! (table 1)
echo $?
! (table -1)
echo $?
! (table 2 a b c)
echo $?
! (table 2 a b c d e)
echo $?
! (table 3 a b c d e)
echo $?
! (table 3 a b c d e f g)
fi
