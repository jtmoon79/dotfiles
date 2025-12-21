#!/usr/bin/env bash
#
# from https://unix.stackexchange.com/questions/275868/find-all-hard-linked-files-between-two-directories
#
# the listing will look something like:
#
#     3137 /tmp/fileA
#     3137 /tmp/hardlink1ToFileA
#     3137 /tmp/hardlink2ToFileA
#

set -eux

(
    # list files with multiple hardlinks
    find "${@}" -xdev -xtype f -links +1 -printf '%i %p\n';
    # list symlinks
    find -L "${@}" -xdev -xtype l -printf '%i %p → ' -exec readlink {} \;
) \
    | sort -n -k1,1 -k2 \
    | awk \
'{
    same = ($1==last)
    if (!same) {
        save = $0
    } else {
        if (save != "") {
            print save
            save = ""
        }
        print
    }
    last = $1
}'
