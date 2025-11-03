<#
.SYNOPSIS
    Moves all disabled Active Directory users from a specified source OU to a destination OU,
    skipping any users that cannot be moved.

.DESCRIPTION
    This script retrieves all users from a source OU, filters for those who are disabled,
    and then moves them to a new destination OU. It is designed to handle errors on a
    per-user basis, logging a failure message and continuing with the next user if a move fails.
    It requires the Active Directory module for PowerShell.

.PARAMETER SourceOU
    The distinguished name of the Organizational Unit (OU) to search for users.

.PARAMETER DestinationOU
    The distinguished name of the Organizational Unit (OU) where disabled users will be moved.

.EXAMPLE
    # Moves all disabled users from "OU=Active Users,DC=contoso,DC=com"
    # to "OU=Disabled Users,DC=contoso,DC=com", skipping any that fail.
    .\Move-DisabledUsers.ps1 -SourceOU "OU=Active Users,DC=contoso,DC=com" -DestinationOU "OU=Disabled Users,DC=contoso,DC=com"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SourceOU,

    [Parameter(Mandatory = $true)]
    [string]$DestinationOU
)

# Check if the Active Directory module is loaded. If not, try to import it.
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "Active Directory module not found. Please ensure it's installed." -ForegroundColor Red
    return
}

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

Write-Host "Searching for disabled users in: '$SourceOU'..." -ForegroundColor Yellow

try {
    # Get all user objects from the source OU that are disabled
    $usersToMove = Get-ADUser -Filter 'Enabled -eq $false' -SearchBase $SourceOU -ErrorAction Stop

    if ($usersToMove.Count -eq 0) {
        Write-Host "No disabled users found in '$SourceOU'." -ForegroundColor Green
        return
    }

    Write-Host "Found $($usersToMove.Count) disabled user(s)." -ForegroundColor Yellow
    Write-Host "Starting move process..." -ForegroundColor Cyan

    # Loop through each disabled user and attempt to move them
    foreach ($user in $usersToMove) {
        try {
            Write-Host "Attempting to move user: $($user.SamAccountName)" -ForegroundColor White
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $DestinationOU -ErrorAction Stop
            Write-Host "Successfully moved $($user.SamAccountName)." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to move $($user.SamAccountName). Error: $($_.Exception.Message)" -ForegroundColor Red
            # The script will continue to the next user
        }
    }

    Write-Host "`nMove process completed. Check the output for any failed moves." -ForegroundColor Green
}
catch {
    Write-Host "`nAn error occurred during the script execution." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}
