# .bash_logout
#
# built-in customizations for bash
# changes to this file will be overwritten by `dotfiles/install.sh`
# local changes should be put into neighboring .bash_logout.local
#
# executed by bash(1) when login shell exits.

# run local logout activity if it exists
bashrc_source_file "${__bash_profile_path_dir}/.bash_logout.local"

# when leaving the console clear the screen to increase privacy
if [[ "${SHLVL-}" = 1 ]] && [[ -x /usr/bin/clear_console ]]; then
    /usr/bin/clear_console -q
fi
