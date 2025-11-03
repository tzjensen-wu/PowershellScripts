<#
.SYNOPSIS
    Moves all enabled Active Directory users from a specified source OU to a destination OU.

.DESCRIPTION
    This script retrieves all users from a source OU, filters for those who are enabled,
    and then moves them to a new destination OU. It also includes optional parameters
    to filter for users in a specific security group and to exclude an individual user.
    It requires the Active Directory module for PowerShell.

.PARAMETER SourceOU
    The distinguished name of the Organizational Unit (OU) to search for users.

.PARAMETER DestinationOU
    The distinguished name of the Organizational Unit (OU) where users will be moved.

.PARAMETER SecurityGroup
    The name or distinguished name of a security group. Only members of this group
    will be considered for the move operation.

.PARAMETER ExcludeUser
    The SamAccountName of a specific user to exclude from the move operation.

.EXAMPLE
    # Moves all enabled users from "OU=Disabled Users,DC=contoso,DC=com"
    # to "OU=Active Users,DC=contoso,DC=com"
    .\Move-EnabledUsers.ps1 -SourceOU "OU=Disabled Users,DC=contoso,DC=com" -DestinationOU "OU=Active Users,DC=contoso,DC=com"

.EXAMPLE
    # Moves all enabled members of the "SalesTeam" security group
    # from "OU=Disabled Users,DC=contoso,DC=com" to "OU=Active Users,DC=contoso,DC=com"
    .\Move-EnabledUsers.ps1 -SourceOU "OU=Disabled Users,DC=contoso,DC=com" -DestinationOU "OU=Active Users,DC=contoso,DC=com" -SecurityGroup "SalesTeam"

.EXAMPLE
    # Moves all enabled members of the "SalesTeam" security group, but excludes "jdoe"
    .\Move-EnabledUsers.ps1 -SourceOU "OU=Disabled Users,DC=contoso,DC=com" -DestinationOU "OU=Active Users,DC=contoso,DC=com" -SecurityGroup "SalesTeam" -ExcludeUser "jdoe"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SourceOU,

    [Parameter(Mandatory = $true)]
    [string]$DestinationOU,

    [Parameter(Mandatory = $false)]
    [string]$SecurityGroup,

    [Parameter(Mandatory = $false)]
    [string]$ExcludeUser
)

# Check if the Active Directory module is loaded. If not, try to import it.
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "Active Directory module not found. Please ensure it's installed." -ForegroundColor Red
    return
}

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

Write-Host "Searching for enabled users in: '$SourceOU'..." -ForegroundColor Yellow

try {
    # Get all user objects from the source OU that are enabled
    $usersToMove = Get-ADUser -Filter 'Enabled -eq $true' -SearchBase $SourceOU -ErrorAction Stop

    # If a security group is specified, filter the list of users.
    if (-not [string]::IsNullOrEmpty($SecurityGroup)) {
        Write-Host "Filtering for members of group: '$SecurityGroup'..." -ForegroundColor Yellow
        $groupMembers = Get-ADGroupMember -Identity $SecurityGroup -ErrorAction Stop
        $groupMemberDNs = $groupMembers | Select-Object -ExpandProperty DistinguishedName
        $usersToMove = $usersToMove | Where-Object { $_.DistinguishedName -in $groupMemberDNs }
    }

    # If an exclusion user is specified, filter them out.
    if (-not [string]::IsNullOrEmpty($ExcludeUser)) {
        Write-Host "Excluding user '$ExcludeUser' from the move operation..." -ForegroundColor Yellow
        $usersToMove = $usersToMove | Where-Object { $_.SamAccountName -ne $ExcludeUser }
    }

    if ($usersToMove.Count -eq 0) {
        Write-Host "No enabled users to move in '$SourceOU'." -ForegroundColor Green
        return
    }

    Write-Host "Found $($usersToMove.Count) enabled user(s) to move." -ForegroundColor Yellow
    Write-Host "Starting move process..." -ForegroundColor Cyan

    # Loop through each enabled user and move them to the destination OU
    foreach ($user in $usersToMove) {
        Write-Host "Moving user: $($user.SamAccountName)" -ForegroundColor White
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $DestinationOU -ErrorAction Stop
        Write-Host "Successfully moved $($user.SamAccountName)." -ForegroundColor Green
    }

    Write-Host "All enabled users have been moved successfully!" -ForegroundColor Green

}
catch {
    Write-Host "An error occurred during the script execution." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}
