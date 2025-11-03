# Requires the ActiveDirectory module to be installed on the machine
# To install: Install-Module -Name ActiveDirectory

# ------------------------------------------------------------------
#                   Configuration Variables
# ------------------------------------------------------------------

# Specify the names of the two security groups you want to compare
$Group1Name = "group1"  # <--- REPLACE with the name of the first group
$Group2Name = "group2"  # <--- REPLACE with the name of the second group

# Specify the location to save the output CSV file
$OutputFile = "C:\Temp\Common_Users_in_$($Group1Name)_and_$($Group2Name).csv"

# ------------------------------------------------------------------
#                   Script Logic
# ------------------------------------------------------------------

Write-Host "Starting search for common users..." -ForegroundColor Cyan

# 1. Get members of the first group
Write-Host "Getting members of '$Group1Name'..." -ForegroundColor Yellow
try {
    # Get members, filter for only user objects, and select the SamAccountName property
    $Group1Members = Get-ADGroupMember -Identity $Group1Name -Recursive |
                     Where-Object {$_.objectClass -eq 'user'} |
                     Select-Object -ExpandProperty SamAccountName -ErrorAction Stop
}
catch {
    Write-Host "Error accessing '$Group1Name'. Check the group name and try again." -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Get members of the second group
Write-Host "Getting members of '$Group2Name'..." -ForegroundColor Yellow
try {
    # Get members, filter for only user objects, and select the SamAccountName property
    $Group2Members = Get-ADGroupMember -Identity $Group2Name -Recursive |
                     Where-Object {$_.objectClass -eq 'user'} |
                     Select-Object -ExpandProperty SamAccountName -ErrorAction Stop
}
catch {
    Write-Host "Error accessing '$Group2Name'. Check the group name and try again." -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. Compare the two lists
Write-Host "Comparing member lists..." -ForegroundColor Yellow
$CommonUsers = Compare-Object -ReferenceObject $Group1Members -DifferenceObject $Group2Members -IncludeEqual |
               Where-Object {$_.SideIndicator -eq '=='} |
               Select-Object -ExpandProperty InputObject

# 4. Output the results
if ($CommonUsers.Count -gt 0) {
    Write-Host "Found $($CommonUsers.Count) users common to both groups." -ForegroundColor Green
    
    # Format the output as a PSCustomObject for a cleaner CSV
    $OutputData = $CommonUsers | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName  = $_
            Group1          = $Group1Name
            Group2          = $Group2Name
            Status          = "Member of Both"
        }
    }
    
    # Export to CSV
    $OutputData | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Host "Results saved to: $OutputFile" -ForegroundColor Green
    
}
else {
    Write-Host "No common users were found in '$Group1Name' and '$Group2Name'." -ForegroundColor Cyan
}

Write-Host "Script execution complete." -ForegroundColor Cyan