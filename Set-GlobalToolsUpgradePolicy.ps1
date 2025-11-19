<#
.SYNOPSIS
    Sets the global default policy on the vCenter Server to automatically upgrade 
    VMware Tools on the next power-on for newly created virtual machines.

.DESCRIPTION
    This script connects to the specified vCenter and modifies the advanced 
    setting 'config.defaults.tools.upgradePolicy' to 'upgradeAtPowerOn' using the 
    vSphere API (UpdateOptions method). This key is the correct name for the 
    global vCenter configuration setting.

.NOTES
    This setting ONLY affects new VMs created AFTER the policy is applied. 
    Existing VMs maintain their current, explicit configuration unless their 
    individual setting is removed.
    Requires the VMware PowerCLI module.
#>

# --- USER CONFIGURATION START ---

# Specify the vCenter Server name or IP address
$vCenterServer = "vcenter.net.pvt"

# Specify the credentials for connection (will prompt for password)
$cred = Get-Credential -Message "Enter vCenter credentials for $($vCenterServer)"

# The vCenter advanced setting key for the global default tools policy
# *** FIX APPLIED: Changed to the correct global key name ***
$globalSettingName = "config.defaults.tools.upgradePolicy"
# The value that forces the upgrade on power-on
$globalSettingValue = "upgradeAtPowerOn"

# --- USER CONFIGURATION END ---

# Suppress certificate warnings (optional)
Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

Write-Host "Connecting to vCenter: $($vCenterServer)..." -ForegroundColor Yellow
try {
    # Connect to the vCenter server and store the connection object
    $viserver = Connect-VIServer -Server $vCenterServer -Credential $cred -ErrorAction Stop
    Write-Host "Successfully connected to vCenter." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to vCenter server $($vCenterServer). Error: $($_.Exception.Message)"
    exit 1
}

try {
    Write-Host "Attempting to set global vCenter default: $($globalSettingName) = '$globalSettingValue'..." -ForegroundColor Yellow
    
    # 1. Get the SettingManager object via the connected server's ExtensionData.
    $settingManager = Get-View $viserver.ExtensionData.Content.Setting
    
    # 2. Create the OptionValue object required for the UpdateOptions method.
    $optionValue = New-Object VMware.Vim.OptionValue
    $optionValue.Key = $globalSettingName
    $optionValue.Value = $globalSettingValue

    # 3. Apply the configuration change using the vSphere API UpdateOptions method.
    # This method is the most robust way to set vCenter-level advanced settings.
    $settingManager.UpdateOptions($optionValue)
    
    Write-Host "SUCCESS: Global vCenter setting applied." -ForegroundColor Green
    Write-Host "The global default policy for new VMs is now set to 'Upgrade VMware Tools on boot'." -ForegroundColor Cyan
}
catch {
    Write-Error "FAILED to set the global configuration. Error: $($_.Exception.Message)"
}
finally {
    # 4. Disconnect from vCenter
    Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
    Disconnect-VIServer -Confirm:$false
}