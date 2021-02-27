#!/usr/bin/env bash
#
# setup single system-wide ssh-agent process. Export $SSH_AUTH_SOCK
# for $USER.
#
# Pro-tip: have your ~/.bashrc `source ~/.ssh/ssh-auth-sock`
#
# Designed against ssh-agent from package ssh-client version OpenSSH_7.6

set -e
set -u
set -o pipefail

if [[ -f "${USER}/.ssh/ssh-auth-sock" ]]; then
    source "${USER}/.ssh/ssh-auth-sock"
elif [[ -f "$(dirname -- "${0}")/ssh-auth-sock" ]]; then
    source "$(dirname -- "${0}")/ssh-auth-sock"
else
    echo "ERROR: cannot find ssh-auth-sock file" >&2
    exit 1
fi

mkdir -vp -- "${SSH_AUTH_SOCKD}"
# $USER is *nix, $USERNAME is MinGW bash
chown -v "${USER-${USERNAME-}}:" -- "${SSH_AUTH_SOCKD}"
chmod -v 0700 -- "${SSH_AUTH_SOCKD}"
# first `ps` is *nix, second `ps` is MinGW bash
psout=$(ps -A -o 'cmd' || ps --all)
if ! (echo "${psout}" | grep -qFe "ssh-agent -a ${SSH_AUTH_SOCK}"); then
(
    rm -fv -- "${SSH_AUTH_SOCK}"
    set -x
    ssh-agent -a "${SSH_AUTH_SOCK}"
)
fi
ssh-add -l
