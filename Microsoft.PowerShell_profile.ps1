# Custom Windows Powershell
#
# startup writes
#
#    Powershell 5.1.18362.145
#
# adds custom aliases
#
# copy this file to $env:HOMEPATH\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# this file is available at https://github.com/jtmoon79/dotfiles/blob/master/Microsoft.PowerShell_profile.ps1

# writes once on startup
Write-Host "Powershell" $PSVersionTable.PSVersion "`n"

#
# custom aliases
#

try
{
    # two ways to create an alias, New-Alias and New-Item
    # XXX: set the "Source" property to this script (seen in the `alias` command)
    New-Alias -Name "which" -Description "just like Unix!" -Value Get-Command -Option Constant -ErrorAction SilentlyContinue
    New-Item -path alias:np -value c:\windows\notepad.exe -ErrorAction SilentlyContinue | Out-Null
} catch {
    # pass
}

function Print-Env {
	Get-ChildItem env:* | Sort-Object Name
}
New-Alias -Name "env" -Description "sorta' like Unix!" -Value Print-Env -ErrorAction SilentlyContinue

#
# prompt improvement
#

# copied from https://stackoverflow.com/a/46991468/471376
function prompt {
    Write-Host "[$Env:username@$Env:computername] " -NoNewline
    Write-Host "$($PWD.ProviderPath) " -ForegroundColor Cyan -NoNewline
    Write-Host "`nPS>" -NoNewline
    return " "  # must return something or else powershell will automatically tack on "PS>"
}

# run Linux Substystem "vim" program like it's a normal Windows program
# something like an alias but really a shortcut to Windows Linux Subsystem vim application
function vim ($File){
    # XXX: need to allow variable length argument list so "vim" can be passed options
    $File = $File -replace '\\', '/'
    bash -c "vim -- '$File'"
}
