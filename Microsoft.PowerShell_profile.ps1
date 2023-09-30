# Microsoft_PowerShell_profile.ps1
#
# Custom Windows Powershell profile.
#
# Install this with helper script `install-profile.ps1`.
# See intructions within that script.
#
# Or manually copy this file to ${env:HOMEPATH}\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#
# This file is available at https://github.com/jtmoon79/dotfiles/blob/master/Microsoft.PowerShell_profile.ps1
#

# add $PSCommandPath if does not exist (for Powershell prior to 3.0)
if ($PSCommandPath -eq $null) {
    function GetPSCommandPath() {
        return $MyInvocation.PSCommandPath;
    }
    $PSCommandPath = GetPSCommandPath
}

if ((Get-Variable -Name PSCommandPath -Scope Global -ErrorAction SilentlyContinue) -and ($PSCommandPath -ne $null) -and ($PSCommandPath -ne "")) {
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

function global:Print-Env() {
    <#
    .SYNOPSIS
        Print environment variables nicely.
    #>
    Get-ChildItem env:* | Sort-Object Name
}
Write-Host "defined Print-Env()" -ForegroundColor DarkGreen

function global:Print-Path()
{
    <#
    .SYNOPSIS
        Print `PATH` environment variable in a more readable manner.
        Include Registry settings that effect Path searches.
    #>
    $env:Path -replace ";","`n"

    reg.exe QUERY "HKEY_CURRENT_USER\Environment" /f Path /t REG_EXPAND_SZ
    reg.exe QUERY "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /f Path /t REG_EXPAND_SZ
}
Write-Host "defined Print-Path()" -ForegroundColor DarkGreen

# handy functions "Where am I?"
# ripped from https://stackoverflow.com/a/43643346
 function global:PSCommandPath() {
    <#
    .SYNOPSIS
        Which powershell is running?
    #>
    return $PSCommandPath
}
Write-Host "defined PSCommandPath()" -ForegroundColor DarkGreen

function global:ScriptName() {
    <#
    .SYNOPSIS
        The name of the running script.
    #>
    return $MyInvocation.ScriptName
}
Write-Host "defined Print-Path" -ForegroundColor DarkGreen

function global:MyCommandName() {
    return $MyInvocation.MyCommand.Name
}
Write-Host "defined MyCommandName()" -ForegroundColor DarkGreen

function global:MyCommandDefinition() {
    return $MyInvocation.MyCommand.Definition
}
Write-Host "defined MyCommandDefinition()" -ForegroundColor DarkGreen

function global:MyInvocationPSCommandPath() {
    return $MyInvocation.PSCommandPath
}
Write-Host "defined MyInvocationPSCommandPath()" -ForegroundColor DarkGreen

function global:Get-CmdletAlias ($cmdlet_name) {
    <#
    .SYNOPSIS
        Lists aliases for a cmdlet
    .EXAMPLE
        Get-CmdletAlias dir
    #>
    # copied from https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.3
    Get-Alias | `
      Where-Object -FilterScript {$_.Definition -like "$cmdlet_name"} | `
        Format-Table -Property Definition,Name -AutoSize
}
Write-Host "defined Get-CmdletAlias(cmdlet_name)" -ForegroundColor DarkGreen

Function global:Test-CommandExists
{
    <#
    .SYNOPSIS
        Test if a command exists.
    .EXAMPLE
        Test-CommandExists notepad++.exe
    .PARAMETER command
        The command to search for as a string.
    #>
    # copied from https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if(Get-Command $command){
            return $true
        }
    }
    Catch {
        return $false
    }
    Finally {
        $ErrorActionPreference = $oldPreference
    }
    return $false
}
Write-Host "defined Test-CommandExists()" -ForegroundColor DarkGreen

# inspired from from https://devblogs.microsoft.com/powershell/format-xml/
function global:Format-XML ($xml_file, $indent=2)
{
    <#
    .SYNOPSIS
        Print an XML file nicely.
    .PARAMETER xml_file
        the file path
    .PARAMETER indent
        count of leading blank spaces
    .EXAMPLE
        Format-XML "C:\path\to\file.xml" -indent 4
    #>
    $xml = [xml](Get-Content -Path $xml_file)
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}
Write-Host "defined Format-XML(xml_file, indent=2)" -ForegroundColor DarkGreen

function global:Update-This-Profile()
{
    <#
    .SYNOPSIS
        Update all Powershell profiles from remote source.
    .EXAMPLE
        Update-This-Profile
    .DESCRIPTION
        Update all Powershell profiles from the remote source
        https://github.com/jtmoon79/dotfiles/
        to the latest version.
        This will create or overwrite the Powershell profiles to locations used
        by new Powershell versions (Powershell 6 and newer) and old Powershell
        versions (Powershell 5 and older).

        Only one Powershell profile with modifying behavior will be created
        at `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` for
        local sytem User profile and OneDrive profile if available.

        Other profile locations merely acknowledge they have run, i.e.
        `Documents/PowerShell/Profile.ps1`.

        The user can provide a local profile at
        `Documents/PowerShell/Microsoft.PowerShell_profile.local.ps1`
        will be imported by
        `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`.
        The local profile will not be overwritten by this function.
        $PROFILE_LOCAL will refer to that file if it exists.
    #>

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
Write-Host "defined Update-This-Profile()" -ForegroundColor DarkGreen

#
# custom aliases
#

try
{
    # two ways to create an alias, New-Alias and New-Item
    New-Alias -Name "which" -Description "just like Unix!" -Value Get-Command -Option Constant -ErrorAction SilentlyContinue
    # XXX: how to set Source property to "Microsoft.PowerShell_profile.ps1" ? This can be seen as a column in the `alias` command
    New-Item -path alias:np -value 'c:\windows\notepad.exe' -ErrorAction SilentlyContinue | Out-Null
} catch {}

New-Alias -Name "env" -Description "sorta' like Unix!" -Value Print-Env -ErrorAction SilentlyContinue

function global:vim ($File){
    <#
    .SYNOPSIS
        Wrapper to run Linux "vim" like it's a "normal" Windows program.

        Something like an alias but really a shortcut to Windows Linux Subsystem vim application
    #>
    if (-not (Test-CommandExists "bash.exe")) {
        return
    }
    $File = $File -replace "\\", "/"
    bash.exe -c vim -- "'$File'"
}

#
# prompt improvement
#

function global:Prompt {
    Write-Host "[$Env:username@$Env:computername] " -NoNewline
    Write-Host "$($PWD.ProviderPath) " -ForegroundColor Cyan -NoNewline
    Write-Host "`nPS>" -NoNewline
    return " "  # must return something or else powershell will automatically tack on "PS>"
}
Write-Host "defined Prompt" -ForegroundColor DarkGreen

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path -Path $ChocolateyProfile) {
    Write-Host "Import-Module `"${ChocolateyProfile}`"" -ForegroundColor Yellow
    Import-Module "$ChocolateyProfile"
}

# check for a local profile to run
$PROFILE_DIR = $(Get-Item -Path $PROFILE).Directory
if (($null -ne $PROFILE_DIR) -and (Test-Path -Path $PROFILE_DIR)) {
    $PROFILE_LOCAL = Join-Path -Path $PROFILE_DIR -ChildPath "Microsoft_PowerShell_profile.local.ps1"
    if (($null -ne $PROFILE_LOCAL) -and (Test-Path -Path $PROFILE_LOCAL)) {
        Write-Host ". '$PROFILE_LOCAL'" -ForegroundColor DarkYellow
        . $PROFILE_LOCAL
    } else {
        Write-Host "No local profile found at '$($PROFILE_LOCAL)'" -ForegroundColor DarkGray
        Remove-Variable -Name "PROFILE_LOCAL"
    }
}
