# install-profile.ps1
#
# install the Microsoft.PowerShell_profile.ps1 and run `Update-This-Profile`
#
# Run this:
#
#    $(Invoke-WebRequest -Uri "https://gist.githubusercontent.com/jtmoon79/ea855a1797e012921c634339ecb4fc40/raw/22735dc95bc28cfbadab2d568d42b8491cba4cfb/install-profile.ps1").Content | powershell -NoLogo -NoProfile -NonInteractive -Command -

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/jtmoon79/dotfiles/master/Microsoft.PowerShell_profile.ps1" `
    -OutFile $PROFILE `
    -Verbose

Write-Verbose ". '$PROFILE'"
. $PROFILE

Update-This-Profile
