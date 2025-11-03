# Import the Active Directory module
Import-Module ActiveDirectory

# Get the count of enabled users in the domain
$enabledUserCount = (Get-ADUser -Filter {Enabled -eq $true}).Count

# Output the count
Write-Output "Enabled user count: $enabledUserCount"