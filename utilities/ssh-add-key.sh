#!/usr/bin/env bash
#
# ssh-add a key in an automated manner

set -eu

if [[ ${#} -ne 2 ]]; then
    (
        script=$(basename "${0}")
        echo "usage:"
        echo "    ${script} key-file passphrase"
        echo
        echo "Add a ssh key file to the ssh agent using ssh-add in a scripted manner."
        echo
        echo "Example:"
        echo
        echo "   ${script} ~/.ssh/my-private-key.key pa55phrAse"
        echo
        echo "WARNING: passing a secret on the command-line is considered insecure!"
    ) >&2
    exit 1
fi

for prog in ssh-add setsid; do
    if ! which "$prog" &>/dev/null; then
        echo "ERROR missing program $prog" >&2
        exit 1
    fi
done

key=${1}
pass=${2}

# pass cannot have `' characters
if (echo -n "$pass" | grep -qFe "'") || (echo -n "$pass" | grep -qFe '`'); then
    echo "ERROR passphrase cannot have a ' or \` character" >&2
    exit 1
fi

# create temp file, prefer a RAM-backed directory
# mode='u=rwx,g=,o='
if [[ -d /run/shm ]]; then
    TMPF=$(TMPDIR=/run/shm/ mktemp)
else
    TMPF=$(mktemp)
fi
function exit_ {
    rm -f "${TMPF}"
}
trap exit_ EXIT
# XXX: mktemp fails to set with 'x'
chmod u+x "${TMPF}"

# To workaround `ssh-add` awkward handling of automated stdin for
# the key passphrase, give `ssh-add` a script that will only echo the passphrase.
# This script is used for the `$SSH_ASKPASS`.
# Other options like `SSH_ASKPASS=cat` failed because `cat` tries to read the
# `ssh-add` stdout prompt "Enter a passphrase for ..." as a file path.
echo -n "#!/usr/bin/env bash
echo -n \"${pass}\"" > "${TMPF}"

if ! (
    set -x
    declare -xg DISPLAY=
    declare -xg SSH_ASKPASS_REQUIRE=force
    declare -xg SSH_ASKPASS="${TMPF}"
    # must use `setsid` to avoid this failure from ssh-add
    #
    #   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #   @         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
    #   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #   Permissions 0644 for '/tmp/pass' are too open.
    #   It is required that your private key files are NOT accessible by others.
    #   This private key will be ignored.
    #
    setsid -w ssh-add -vvv "${key}"
); then
   exit 1
fi
