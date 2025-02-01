# install-profile.ps1
#
# install the Microsoft.PowerShell_profile.ps1 and run `Update-This-Profile`
#
# Run this script remotely:
#
#    $(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jtmoon79/dotfiles/master/install-profile.ps1").Content | powershell -NoLogo -NoProfile -NonInteractive -Command -
#
# Invoke this profile without copying to $PROFILE
#
#    Invoke-Expression $(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jtmoon79/dotfiles/master/Microsoft.PowerShell_profile.ps1").Content
#

$ProfileInfo = [System.IO.FileInfo]$PROFILE
if (-not (Test-Path $ProfileInfo.DirectoryName)) {
    New-Item -Type Directory -Path $ProfileInfo.DirectoryName
}

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/jtmoon79/dotfiles/master/Microsoft.PowerShell_profile.ps1" `
    -OutFile $PROFILE `
    -Verbose

Write-Verbose ". '$PROFILE'"
. $PROFILE

Update-This-Profile
