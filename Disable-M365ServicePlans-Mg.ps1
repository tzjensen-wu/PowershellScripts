# Requires the Microsoft.Graph module. Install it if necessary: Install-Module Microsoft.Graph

<#
.SYNOPSIS
Disables specific service plans within a Microsoft 365 license SKU for all assigned users using Microsoft Graph PowerShell.

.DESCRIPTION
This script connects to the Microsoft Graph service, retrieves the full list of service plans for a specified license SKU,
identifies the Service Plan IDs to disable, and then applies the updated license configuration to every user
currently assigned the base license. It correctly preserves any existing disabled services for each user.

.PARAMETER LicenseSkuPartName
The License SKU Part Number (e.g., 'ENTERPRISEPACK' for E3, 'STANDARDPACK' for Business Standard).
This is the license you want to modify the services for.

.EXAMPLE
# Connect first with the required scopes (User.ReadWrite.All is essential for license updates)
Connect-MgGraph -Scopes "User.Read.All", "User.ReadWrite.All", "Organization.Read.All"

# Run the script
.\Disable-M365ServicePlans-Mg.ps1 -LicenseSkuPartName ENTERPRISEPACK

.NOTES
1. You must connect to Microsoft Graph *before* running this script using the command shown in the example.
2. The scopes "User.ReadWrite.All", "User.Read.All", and "Organization.Read.All" are required.
3. The script targets the most common service plan names for OneDrive and Teams. Update the 
   $ServiceNamesToDisable array if your tenant uses different names.
4. To find the subscription SKUs use: Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId
5. https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference See the lookup table
Office 365 A1 Plus for Faculty	STANDARDWOFFPACK_IW_FACULTY
Office 365 A1 for students	STANDARDWOFFPACK_STUDENT
Office 365 A1 for faculty	STANDARDWOFFPACK_FACULTY
Microsoft 365 A3 student use benefits	M365EDU_A3_STUUSEBNFT
Microsoft 365 A3 for faculty	M365EDU_A3_FACULTY
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$LicenseSkuPartName
)

# --- Service Plans to Disable ---
$ServiceNamesToDisable = @("TEAMS1", "SHAREPOINTWAC", "SHAREPOINTENTERPRISE")
# --------------------------------

# 1. Check for Active Connection
if (-not (Get-MgContext)) {
    Write-Error "Not connected to Microsoft Graph. Please run 'Connect-MgGraph -Scopes ""User.ReadWrite.All"", ""Directory.Read.All""' first."
    exit 1
}

# 2. Get the Target License SKU details and Service Plan IDs
Write-Host "`n--- Retrieving License Information ---" -ForegroundColor Cyan
$TargetLicenseSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $LicenseSkuPartName }

if (-not $TargetLicenseSku) {
    Write-Error "License SKU '$LicenseSkuPartName' not found. Please check the SkuPartNumber."
    exit 1
}

$TargetSkuId = $TargetLicenseSku.SkuId
$NewDisabledServicePlanIds = @()

# Map service names to their GUID IDs
foreach ($ServiceName in $ServiceNamesToDisable) {
    $ServicePlan = $TargetLicenseSku.ServicePlans | Where-Object { $_.ServicePlanName -eq $ServiceName }
    if ($ServicePlan) {
        $NewDisabledServicePlanIds += $ServicePlan.ServicePlanId
    }
    else {
        Write-Warning "Service plan '$ServiceName' not found in SKU '$LicenseSkuPartName'. Check service plan name."
    }
}

Write-Host "SKU ID: $TargetSkuId" -ForegroundColor Yellow
Write-Host "The following service plan IDs will be disabled: $($NewDisabledServicePlanIds -join ', ')" -ForegroundColor Yellow

# 3. Get Users with the Target License
Write-Host "`n--- Searching for Users with License '$LicenseSkuPartName' ---" -ForegroundColor Cyan

# Use a filter for better performance, as recommended by Microsoft Graph best practices.
$Filter = "assignedLicenses/any(l:l/skuId eq '$($TargetSkuId)')"

# Only select the properties we need (ID is necessary for Get-MgUserLicenseDetail)
$UsersToModify = Get-MgUser -All -Filter $Filter -Select Id, UserPrincipalName

Write-Host "Found $($UsersToModify.Count) user(s) to process." -ForegroundColor Magenta

# 4. Iterate and Apply the Modified License
$Counter = 0
foreach ($User in $UsersToModify) {
    $Counter++
    $userUPN = $User.UserPrincipalName
    Write-Host "`n$Counter/$($UsersToModify.Count): Modifying license for user $userUPN..." -ForegroundColor White

    try {
        # **MSGraph Logic Change:** Get the user's current license details to preserve existing disabled plans.
        $userLicenseDetail = Get-MgUserLicenseDetail -UserId $userUPN

        # Filter for plans already disabled on the target SKU.
        $AlreadyDisabledServicePlanIds = $userLicenseDetail.ServicePlans | Where-Object { 
            ($_.ProvisioningStatus -eq "Disabled") -and 
            ($TargetLicenseSku.ServicePlans.ServicePlanId -contains $_.ServicePlanId)
        } | Select-Object -ExpandProperty ServicePlanId

        # Merge the already disabled plans with the new plans to disable.
        # Set-MgUserLicense requires the full, consolidated list of all plans to be disabled on the SKU.
        $AllDisabledPlans = ($AlreadyDisabledServicePlanIds + $NewDisabledServicePlanIds) | Select-Object -Unique

        # Create the license assignment object for the Set-MgUserLicense cmdlet.
        $AddLicenses = @(
            @{
                SkuId = $TargetSkuId
                DisabledPlans = $AllDisabledPlans
            }
        )

        # Update the user's license. -RemoveLicenses is @() because we're not removing the whole license.
        Set-MgUserLicense -UserId $User.Id -AddLicenses $AddLicenses -RemoveLicenses @()

        Write-Host "Successfully disabled services for $userUPN." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to modify license for $userUPN. Error: $($_.Exception.Message)"
    }
}

Write-Host "`n------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Script completed. Services disabled for $Counter user(s)." -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan