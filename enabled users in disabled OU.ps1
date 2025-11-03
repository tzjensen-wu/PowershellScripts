# Import the Active Directory module
Import-Module ActiveDirectory

# Specify the target OU
$targetOU = "OU=Disabled Users,DC=Willamette,DC=edu"

# Get all enabled users within the specified OU
$enabledUsers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $targetOU -Properties Name | 
    Select-Object Name, DistinguishedName

# Export the list to a CSV file
$enabledUsers | Export-Csv -Path "EnabledUsersInDisabledOU.csv" -NoTypeInformation

# Display the result
Write-Output "Enabled user list from 'Disabled Users' OU has been saved as EnabledUsersInDisabledOU.csv"