#!/usr/bin/env bash
#
# setup single system-wide ssh-agent process. Export $SSH_AUTH_SOCK
# for $USER.
#
# tip: have ~/.bashrc source ~/.ssh/ssh-auth-sock
#

set -e
set -u
set -o pipefail

source "$(dirname -- "${0}")/ssh-auth-sock"

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
