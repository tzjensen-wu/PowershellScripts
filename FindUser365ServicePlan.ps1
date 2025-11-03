Connect-MgGraph
# --- Configuration ---
$SkuPartNumber = "M365EDU_A3_FACULTY" # e.g., ENTERPRISEPACK for M365 E3
$UserPrincipalName = "tzjensen@willamette.edu"  # A user currently assigned this license
# ---------------------

# 1. Get the target SKU details to retrieve all Service Plan names and IDs.
Write-Host "Fetching all services included in the '$SkuPartNumber' license..." -ForegroundColor Yellow
$Sku = Get-MgSubscribedSku -All | Where-Object {$_.SkuPartNumber -eq $SkuPartNumber}

if (-not $Sku) {
    Write-Error "SKU '$SkuPartNumber' not found in your tenant."
    return
}

$AllServicePlans = $Sku.ServicePlans | Select-Object ServicePlanName, ServicePlanId

# 2. Get the target user's license details.
Write-Host "Fetching disabled services for user '$UserPrincipalName'..." -ForegroundColor Yellow
$UserLicenseDetails = Get-MgUserLicenseDetail -UserId $UserPrincipalName

if (-not $UserLicenseDetails) {
    Write-Error "User '$UserPrincipalName' not found or is unlicensed."
    return
}

# 3. Find the specific SKU assigned to the user and its disabled plans.
$UserAssignedSku = $UserLicenseDetails | Where-Object {$_.SkuId -eq $Sku.SkuId}
$DisabledPlansIds = $UserAssignedSku.DisabledPlans

# 4. Generate the final report
$Report = $AllServicePlans | ForEach-Object {
    [PSCustomObject]@{
        ServicePlanName  = $_.ServicePlanName
        ServicePlanId    = $_.ServicePlanId
        ProvisioningStatus = if ($DisabledPlansIds -contains $_.ServicePlanId) {"Disabled"} else {"Enabled"}
    }
}

# Output the results
Write-Host "`n--- Service Plan Status for $UserPrincipalName's $SkuPartNumber License ---" -ForegroundColor Cyan
$Report | Sort-Object ProvisioningStatus, ServicePlanName | Format-Table -AutoSize