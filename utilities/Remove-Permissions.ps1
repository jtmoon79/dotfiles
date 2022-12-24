#!powershell
#
# Remove-Permissions.ps1

<#
    Remove all permissions from the path.
#>
param (
    [Parameter(Mandatory=$true)]
	[System.String]
    $path
)

function Remove-ACLEntries
{
    [CmdletBinding()]
    param(
        [string]$File
    )
    $authusers = (
        (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-11').Translate([System.Security.Principal.NTAccount])
        ).Value
    $acl = Get-Acl $File
    $acl.SetAccessRuleProtection($True, $False)
    $owner = $acl.owner;
    For($i=$acl.Access.Count - 1; $i -gt 0; $i--)
    {
        $rule = $acl.Access[$i]
        if ($rule.IdentityReference -ne $owner -or $rule.IdentityReference -eq $authusers) 
        {
            $acl.RemoveAccessRule($rule)
        }
    }
    Set-ACL -Path $file -AclObject $acl | Out-Null
}

Remove-ACLEntries $path
