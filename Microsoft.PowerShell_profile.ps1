# Microsoft_PowerShell_profile.ps1
#
# Custom Windows Powershell profile.
#
# First install of this profile with helper script `install-profile.ps1`. See
# intructions within that script.
# Subsequent updates to this profile only need to call `Update-This-Profile`.
#
# This file is available at https://github.com/jtmoon79/dotfiles/blob/master/Microsoft.PowerShell_profile.ps1
#

# Force `$global:_PromptStopwatch` to restart to simulate a new process.
# Most likely this is a new process but sometimes this $PROFILE needs to be
# tested (manually run again after the start of the shell) so have it behave liks it's new.
$global:_PromptStopwatch = [System.Diagnostics.Stopwatch]::new()
$global:_PromptStopwatch.Start()

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
    Get-ChildItem env:* | Select-Object -Property Name,Value | Sort-Object Name
}
Write-Host "defined Print-Env()" -ForegroundColor DarkGreen

function global:Print-Path()
{
    <#
    .SYNOPSIS
        Print `PATH` environment variable in a more readable manner.
        Include Registry settings that define the path.
    #>
    Write-Host "env:Path" -ForegroundColor Yellow
    $env:Path -replace ";","`n"

    Write-Host "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\Path" -ForegroundColor Yellow
    $(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "Path").Path `
        -replace ";","`n"

    Write-Host ""
    Write-Host "HKCU:\Environment\Path" -ForegroundColor Yellow
    $(Get-ItemProperty -Path "HKCU:\Environment" -Name "Path").Path -replace ";","`n"
}
Write-Host "defined Print-Path()" -ForegroundColor DarkGreen

# handy functions "Where am I?"
 function global:PSCommandPath() {
    <#
    .SYNOPSIS
        Which powershell is running?

        Inspired from https://stackoverflow.com/a/43643346
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

        Inspired from https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.3
    .EXAMPLE
        Get-CmdletAlias dir
    #>
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
    Param ($command)
    if (Get-Command -Name $command -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}
Write-Host "defined Test-CommandExists()" -ForegroundColor DarkGreen

function global:Format-XML ($xml_file, $indent=2)
{
    <#
    .SYNOPSIS
        Print an XML file nicely.

        Inspired from from https://devblogs.microsoft.com/powershell/format-xml/
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

function global:Print-ProcessTree() {
    <#
    .SYNOPSIS
        Print an all processes as an indented tree.

        Modified from https://superuser.com/a/1817805/167043
    .EXAMPLE
        Print-ProcessTree
    #>

    function Get-ProcessAndChildProcesses($Level, $Process) {
        "{0}[{1,-5}] [{2}]" -f ("  " * $Level), $Process.ProcessId, $Process.Name
        $Children = $AllProcesses | where-object {$_.ParentProcessId -eq $Process.ProcessId -and $_.CreationDate -ge $Process.CreationDate}
        if ($null -ne $Children) {
            foreach ($Child in $Children) {
                Get-ProcessAndChildProcesses ($Level + 1) $Child
            }
        }
    }

    $AllProcesses = Get-CimInstance -ClassName "win32_process"
    $RootProcesses = @()
    # Process "System Idle Process" is processed differently, as ProcessId and ParentProcessId are 0
    # $AllProcesses is sliced from index 1 to the end of the array
    foreach ($Process in $AllProcesses[1..($AllProcesses.length-1)]) {
        $Parent = $AllProcesses | where-object {$_.ProcessId -eq $Process.ParentProcessId -and $_.CreationDate -lt $Process.CreationDate}
        if ($null -eq $Parent) {
            $RootProcesses += $Process
        }
    }
    # Process the "System Idle process" separately
    "[{0,-5}] [{1}]" -f $AllProcesses[0].ProcessId, $AllProcesses[0].Name
    foreach ($Process in $RootProcesses) {
        Get-ProcessAndChildProcesses 0 $Process
    }
}
Write-Host "defined Print-ProcessTree" -ForegroundColor DarkGreen

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

    $default_profile_content = `
'$env:POWERSHELL_UPDATECHECK = "Off"

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
    Set-Content -Path $path1 -Verbose -Value `
"# $path1
# generated by Microsoft.PowerShell_profile.ps1:Update-This-Profile() on $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
"
    Add-Content -Path $path1 -Value $default_profile_content -Verbose

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
    Set-Content -Path $path1 -Verbose -Value `
"# $path1
# generated by Microsoft.PowerShell_profile.ps1:Update-This-Profile() on $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
"
    Add-Content -Path $path1 -Value $default_profile_content -Verbose
    # run the main profile from this profile
    $profile_addon = '
# import the main profile
& "' + $path_profile6 + '"'
    Add-Content -Path $path1 -Value $profile_addon -Verbose
    # Current User, All Hosts
    $path1 = Join-Path -Path $pathItem -ChildPath "Profile.ps1"
    Write-Host "create '$path1'" -ForegroundColor Yellow
    Set-Content -Path $path1 -Verbose -Value `
"# $path1
# generated by Microsoft.PowerShell_profile.ps1:Update-This-Profile() on $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
"
    Add-Content -Path $path1 -Value $default_profile_content -Verbose
}
Write-Host "defined Update-This-Profile()" -ForegroundColor DarkGreen

#
# custom aliases
#

New-Alias -Name "which" -Description "just like Unix!" -Value Get-Command -Scope Global -Option Constant -ErrorAction SilentlyContinue
if ($?) {
    Write-Host "added alias which" -ForegroundColor DarkGreen
}
if (Test-Path 'C:\windows\notepad.exe') {
    New-Alias -Name "np" -Value 'C:\windows\notepad.exe' -Scope Global -Option Constant -ErrorAction SilentlyContinue
    if ($?) {
        Write-Host "added alias np" -ForegroundColor DarkGreen
    }
}
New-Alias -Name "l" -Value Get-ChildItem -Scope Global -Option Constant -ErrorAction SilentlyContinue
if ($?) {
    Write-Host "added alias l" -ForegroundColor DarkGreen
}
New-Alias -Name "env" -Description "sorta' like Unix!" -Value Print-Env -Scope Global -Option Constant -ErrorAction SilentlyContinue
if ($?) {
    Write-Host "added alias env" -ForegroundColor DarkGreen
}

if (-not (Test-CommandExists "bash.exe")) {
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
    Write-Host "defined vim()" -ForegroundColor DarkGreen
}

function global:Unicode {
    <#
    .SYNOPSIS
    Takes in a stream of strings and integers,
    where integers are unicode codepoints,
    and concatenates these into valid UTF16.

    Derived from https://stackoverflow.com/a/60825403/471376
    #>
    Begin {
        $output=[System.Text.StringBuilder]::new()
    }
    Process {
        $output.Append($(
            if ($_ -is [int]) { [char]::ConvertFromUtf32($_) }
            else { [string]$_ }
        )) | Out-Null
    }
    End {
        $output.ToString()
    }
}
Write-Host "defined Unicode()" -ForegroundColor DarkGreen

#
# prompt improvement
#

function global:Prompt {
    <#
    .SYNOPSIS
        The singular global Prompt function.
        TODO: presumes dark background, need to handle light color background
    #>
    if ($null -ne $global:_PromptStopwatch) {
        $p4a = '({0,6:n2}s) ' -f $global:_PromptStopwatch.Elapsed.TotalSeconds
    } else {
        $global:_PromptStopwatch = [System.Diagnostics.Stopwatch]::new()
        $p4a = '() '
    }
    # only need to define these once, it's presumed they take a bit of work to retrieve
    # so don't run this on every prompt
    if ($null -eq $global:_PromptFirstRun) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal] $identity
        $global:_PromptUserName = $identity.Name
        $global:_PromptCompName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
        $global:_PromptIsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $global:_PromptFirstRun = $True
    }
    # assemble pieces of the first line of the prompt
    $p1 = $global:_PromptUserName
    $p2 = '@'
    $p3 = $global:_PromptCompName
    $p3b = ' '
    $p4 = Get-Date -Format "[yyyy-MM-ddTHH:mm:ss] "
    $len1234 = $p1.Length + $p2.Length + $p3.Length + $p3b.Length + $p4.Length + $p4a.Length
    $p5 = $PWD.ProviderPath
    # write the prompt pieces with colors
    if ($global:_PromptIsAdmin) {
        Write-Host $p1 -ForegroundColor Red -NoNewline
    } else {
        Write-Host $p1 -ForegroundColor Blue -NoNewline
    }
    Write-Host $p2 -NoNewline
    Write-Host $p3 -ForegroundColor Blue -NoNewline
    Write-Host $p3b -NoNewline
    Write-Host $p4 -ForegroundColor Green -NoNewline
    Write-Host $p4a -ForegroundColor Gray -NoNewline
    $lenC = $Host.UI.RawUI.WindowSize.Width + 1
    if ($lenC -lt 0) {
        $lenC = 2
    }
    if ($lenC -gt $len1234 + $p5.Length) {
        Write-Host $p5 -ForegroundColor White
    } elseif (($lenC -lt $len1234 + $p5.Length) -and ($lenC -gt $len1234)) {
        # XXX: PowerShell 5 prints '…' as 'â€¦'
        $append = ' '
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $append = '…'
        }
        Write-Host ($p5.Substring(0, $lenC - $len1234 - 2) + $append) -ForegroundColor White
    } else {
        Write-Host ''
    }

    # The second line of the prompt will not be written here but will be a returned string.
    # The running powershell process will write this string to the console.

    # check `$global:_PromptAsciiOnly=$True`, then check `$global:_PromptLead`, finally fallback
    # to returning a default prompt string based on the Version.Major.
    #
    # Note that if nothing or an empty string is returned from this function then
    # powershell will append string 'PS> ' to the prompt.
    if (
        ($null -ne $global:_PromptAsciiOnly) `
        -and ($global:_PromptAsciiOnly -is [System.Boolean]) `
        -and ($True -eq $global:_PromptAsciiOnly)
    ) {
        $global:_PromptStopwatch.Restart()
        return 'PS>'
    } elseif ($null -ne $global:_PromptLead) {
        $global:_PromptStopwatch.Restart()
        if ('' -eq $global:_PromptLead) {
            return ' '
        }
        return "$($global:_PromptLead)"
    } else {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $global:_PromptStopwatch.Restart()
            # XXX: PowerShell 5 will throw an exception if this high-plane unicode is
            #      anywhere in this function (yes, defined anywhere in this *function*, not even in
            #      the returned prompt string itself).
            #      i.e. cannot have this statement:
            #          return '𝓟𝒮 ▷ '
            #      Instead, call `ConvertFromUtf32` to express high-plane unicode chracters
            #      without embedding them in this function.
            #      Idea from https://stackoverflow.com/a/60825495/471376
            #
            #      Additionally, wrap this `return` in `try` in case it throws in some other
            #      context that hasn't been tested. In my experiments with Powershell 5 in a few
            #      contexts, it was surprisingly fragile in the presence of high-plane unicode
            #      characters.
            try {
                # '𝓟𝒮 ▷ '
                return [char]::ConvertFromUtf32(0x1D4DF) + [char]::ConvertFromUtf32(0x1D4AE) + ' ' `
                + [char]::ConvertFromUtf32(0x25B7) + ' '
            }
            catch {
                return 'PS> '
            }
        } else {
            $global:_PromptStopwatch.Restart()
            return 'PS> '
        }
    }
}
$global:_PromptFirstRun = $null  # reset this global switch
Write-Host "defined Prompt" -ForegroundColor DarkGreen -NoNewLine
Write-Host " (turn off unicode with `$global:_PromptAsciiOnly=`$True or define your own `$global:_PromptLead)" -ForegroundColor DarkGray

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "${env:ChocolateyInstall}\helpers\chocolateyProfile.psm1"
if (Test-Path -Path $ChocolateyProfile) {
    Write-Host "Import-Module `"${ChocolateyProfile}`"" -ForegroundColor Yellow
    Import-Module "$ChocolateyProfile"
}

# check for a local profile to run
$PROFILE_DIR = $(Get-Item -Path $PROFILE).Directory
if (($null -ne $PROFILE_DIR) -and (Test-Path -Path $PROFILE_DIR)) {
    $PROFILE_LOCAL = Join-Path -Path $PROFILE_DIR -ChildPath "Microsoft.PowerShell_profile.local.ps1"
    if (($null -ne $PROFILE_LOCAL) -and (Test-Path -Path $PROFILE_LOCAL)) {
        Write-Host ". '$PROFILE_LOCAL'" -ForegroundColor DarkYellow
        . $PROFILE_LOCAL
    } else {
        Write-Host "No local profile found at '$($PROFILE_LOCAL)'" -ForegroundColor DarkGray
        Remove-Variable -Name "PROFILE_LOCAL"
    }
}
