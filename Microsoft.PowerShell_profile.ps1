# Microsoft_PowerShell_profile.ps1
#
# custom Windows Powershell profile
#
# copy this file to ${env:HOMEPATH}\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# this file is available at https://github.com/jtmoon79/dotfiles/blob/master/Microsoft.PowerShell_profile.ps1
#
# copy to your local $PROFILE
#     Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jtmoon79/dotfiles/master/Microsoft.PowerShell_profile.ps1" -OutFile $PROFILE -Verbose
#

if ( (Get-Variable -Name PSCommandPath -Scope Global -ErrorAction SilentlyContinue) -and ($PSCommandPath -ne $null) -and ($PSCommandPath -ne "") ) {
    Write-Host "$PSCommandPath" -ForegroundColor Yellow
}
Write-Host "$(Get-Process -Id $PID | Select-Object -ExpandProperty path) " -Nonewline -ForegroundColor Magenta
Write-Host $PSVersionTable.PSVersion -ForegroundColor Magenta

# turn off check; the check can take tens of seconds on a slow network
$env:POWERSHELL_UPDATECHECK = 'Off'

# force UTF-8
# from https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.2
# https://archive.ph/S8uhz
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

#
# custom functions
#

function Print-Env {
    Get-ChildItem env:* | Sort-Object Name
}

function Print-Path
{
    $env:Path -replace ";","`n"

    reg query "HKEY_CURRENT_USER\Environment" /f Path /t REG_EXPAND_SZ
    reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /f Path /t REG_EXPAND_SZ
}

# handy functions "Where am I?"
# ripped from https://stackoverflow.com/a/43643346
 function PSCommandPath() {
    return $PSCommandPath
}
function ScriptName() {
    return $MyInvocation.ScriptName
}
function MyCommandName() {
    return $MyInvocation.MyCommand.Name
}
function MyCommandDefinition() {
    # Begin of MyCommandDefinition()
    # Note: output of this script shows the contents of this function, not the execution result
    return $MyInvocation.MyCommand.Definition
    # End of MyCommandDefinition()
}
function MyInvocationPSCommandPath() {
    return $MyInvocation.PSCommandPath
}

# copied from https://devblogs.microsoft.com/powershell/format-xml/
# use it like:
#      Format-XML ([xml](cat C:\path\to\file.xml)) -indent 4
function Format-XML ([xml]$xml, $indent=2)
{
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}

#
# custom aliases
#

try
{
    # two ways to create an alias, New-Alias and New-Item
    New-Alias -Name "which" -Description "just like Unix!" -Value Get-Command -Option Constant -ErrorAction SilentlyContinue
    # XXX: how to set Source property to "Microsoft.PowerShell_profile.ps1" ? This can be seen as a column in the `alias` command
    New-Item -path alias:np -value c:\windows\notepad.exe -ErrorAction SilentlyContinue | Out-Null
} catch {}

New-Alias -Name "env" -Description "sorta' like Unix!" -Value Print-Env -ErrorAction SilentlyContinue

#
# prompt improvement
#

function global:Prompt {
    Write-Host "[$Env:username@$Env:computername] " -NoNewline
    Write-Host "$($PWD.ProviderPath) " -ForegroundColor Cyan -NoNewline
    Write-Host "`nPS>" -NoNewline
    return " "  # must return something or else powershell will automatically tack on "PS>"
}

#
# something like an alias but really a shortcut to Windows Linux Subsystem vim application
#

# run Linux "vim" like it's a "normal" Windows program
function vim ($File){
    $File = $File -replace "\\", "/"
    bash -c vim -- '$File'
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Write-Host "Import-Module `"${ChocolateyProfile}`"" -ForegroundColor Yellow
    Import-Module "$ChocolateyProfile"
}
