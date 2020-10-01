Scripts for `$USER/.ssh` setup.

    cp -av ssh-agent-start.sh ~/bin/
    cp -av ssh-auth-sock ~/.ssh/
    ln -vs ~/.ssh/ssh-auth-sock ~/bin/ssh-auth-sock

