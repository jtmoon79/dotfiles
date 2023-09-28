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

# add $PSCommandPath if does not exist (for Powershell prior to 3.0)
if ($PSCommandPath -eq $null) {
    function GetPSCommandPath() {
        return $MyInvocation.PSCommandPath;
    }
    $PSCommandPath = GetPSCommandPath
}

if ( (Get-Variable -Name PSCommandPath -Scope Global -ErrorAction SilentlyContinue) -and ($PSCommandPath -ne $null) -and ($PSCommandPath -ne "") ) {
    Write-Host "$PSCommandPath" -ForegroundColor Yellow
}
Write-Host "$(Get-Process -Id $PID | Select-Object -ExpandProperty path) " -Nonewline -ForegroundColor Magenta
Write-Host $PSVersionTable.PSVersion -ForegroundColor Magenta

# turn off check; the check can take tens of seconds on a slow network
$env:POWERSHELL_UPDATECHECK = "Off"

# force UTF-8
# from https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.2
# https://archive.ph/S8uhz
$PSDefaultParameterValues["Out-File:Encoding"] = "utf8"
$PSDefaultParameterValues['*:Encoding'] = "utf8"

#
# custom functions
#

function Print-Env() {
    Get-ChildItem env:* | Sort-Object Name
}

function Print-Path()
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

function Update-This-Profile()
{
    $default_profile_content = '# Profile stub

$env:POWERSHELL_UPDATECHECK = "Off"

# add $PSCommandPath if does not exist (for Powershell prior to 3.0)
if ($PSCommandPath -eq $null) {
    function GetPSCommandPath() {
        return $MyInvocation.PSCommandPath;
    }
    $PSCommandPath = GetPSCommandPath
}

if ( (Get-Variable -Name PSCommandPath -Scope Global -ErrorAction SilentlyContinue) -and ($PSCommandPath -ne $null) -and ($PSCommandPath -ne "") ) {
    Write-Host "$PSCommandPath" -ForegroundColor Yellow
}
'

    $uri = 'https://raw.githubusercontent.com/jtmoon79/dotfiles/master/Microsoft.PowerShell_profile.ps1'

    if (($null -ne $env:OneDrive) -and (Test-Path "${env:OneDrive}\Documents")) {
        $path_root = Resolve-Path -Path "${env:OneDrive}\Documents"
    } elseif (Test-Path "${env:USERPROFILE}\Documents") {
        $path_root = Resolve-Path -Path "${env:USERPROFILE}\Documents"
    } else {
        Write-Warning "Unable to install profile; no Documents directories found"
        return
    }

    # PowerShell 6 and greater
    # see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-6.0

    $path = "${path_root}\PowerShell"
    if (-not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path -Verbose
    }
    $pathItem = Get-Item -Path $path
    # Current User, Current Host
    $path1 = Join-Path -Path $pathItem -ChildPath "Microsoft.PowerShell_profile.ps1"
    $path_profile6 = $path1.Clone()
    Write-Host "create main profile '$path1'" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $uri -OutFile $path1 -Verbose
    # Current User, All Hosts
    $path1 = Join-Path -Path $pathItem -ChildPath "Profile.ps1"
    Write-Host "create '$path1'" -ForegroundColor Yellow
    Set-Content -Path $path1 -Value $default_profile_content -Verbose

    # PowerShell 5
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-5.1

    $path = "${path_root}\WindowsPowershell"
    if (-not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path -Verbose
    }
    $pathItem = Get-Item -Path $path
    # Current User, Current Host
    $path1 = Join-Path -Path $pathItem -ChildPath "Microsoft.PowerShell_profile.ps1"
    Write-Host "create '$path1'" -ForegroundColor Yellow
    Set-Content -Path $path1 -Value $default_profile_content -Verbose
    # run the main profile from this profile
    $profile_addon = '
# import the main profile
& "' + $path_profile6 + '"'
    Add-Content -Path $path1 -Value $profile_addon -Verbose
    # Current User, All Hosts
    $path1 = Join-Path -Path $pathItem -ChildPath "Profile.ps1"
    Write-Host "create '$path1'" -ForegroundColor Yellow
    Set-Content -Path $path1 -Value $default_profile_content -Verbose
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
