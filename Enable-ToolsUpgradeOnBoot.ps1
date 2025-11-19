<#
.SYNOPSIS
    Connects to a vCenter server and enables the 'Upgrade VMware Tools on boot' 
    option for all virtual machines identified as Windows Servers.

.DESCRIPTION
    This script utilizes PowerCLI to modify the advanced configuration setting 
    'tools.upgradePolicy' to 'upgradeAtPowerOn' for filtered VMs. This is the 
    equivalent of checking the 'Check and upgrade Tools during next power on' box 
    in the VM settings within the vSphere Client.

    The script uses the Get-View and ReconfigVM_Task method for compatibility 
    with older PowerCLI versions that may not support the -AdvancedSetting 
    parameter on Set-VM, which fixes the reported error.

.NOTES
    Requires the VMware PowerCLI module. Run this script from a PowerShell session 
    with permissions to manage the specified vCenter.
    Install-Module -Name VMware.PowerCLI
#>

# --- USER CONFIGURATION START ---

# Specify the vCenter Server name or IP address
$vCenterServer = "vcenter.net.pvt"

# Specify the credentials for connection
# IMPORTANT: It is best practice to prompt for credentials rather than hardcoding.
# The script will prompt you when it runs.
# If you must use hardcoded credentials (NOT RECOMMENDED), uncomment the next line and replace placeholders:
# $cred = Get-Credential -UserName "administrator@vsphere.local" -Message "Enter vCenter credentials"
$cred = Get-Credential -Message "Enter vCenter credentials for $($vCenterServer)"

# Filter criteria: Finds VMs where the reported Guest OS name contains "Windows Server".
# Examples: "Microsoft Windows Server 2022 (64-bit)", "Windows Server 2016 (64-bit)"
$osFilter = "*Windows Server*"

# Advanced setting key and value to enable the upgrade on boot policy
$advancedSettingName = "tools.upgradePolicy"
$advancedSettingValue = "upgradeAtPowerOn"

# --- USER CONFIGURATION END ---

# Suppress certificate warnings (optional, but often necessary)
Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

Write-Host "Connecting to vCenter: $($vCenterServer)..." -ForegroundColor Yellow
try {
    # Connect to the vCenter server
    Connect-VIServer -Server $vCenterServer -Credential $cred -ErrorAction Stop
    Write-Host "Successfully connected to vCenter." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to vCenter server $($vCenterServer). Error: $($_.Exception.Message)"
    exit 1
}

try {
    Write-Host "Retrieving all VMs matching OS filter '$osFilter'..." -ForegroundColor Yellow
    
    # 1. Get all VMs and filter them by the reported Guest OS name
    # We include powered off VMs since this setting is applied at power-on.
    $windowsVMs = Get-VM | Where-Object { 
        $_.Guest.OSFullName -like $osFilter
    }

    if (-not $windowsVMs) {
        Write-Host "No VMs found matching the OS filter '$osFilter'. Exiting." -ForegroundColor Cyan
        exit 0
    }
    
    Write-Host "Found $($windowsVMs.Count) Windows Server VMs to process." -ForegroundColor Cyan
    
    $successCount = 0
    $failCount = 0
    
    # 2. Iterate through each filtered VM and apply the advanced setting
    foreach ($vm in $windowsVMs) {
        Write-Host "Processing VM: $($vm.Name)..." -NoNewline
        
        try {
            # Retrieve the VM View object, which allows direct configuration manipulation via the vSphere API.
            $vmView = Get-View -Id $vm.Id -Property Name, Config
            
            # Create the Configuration Specification
            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            
            # Create the Option Value object for the advanced setting
            $opt = New-Object VMware.Vim.OptionValue
            $opt.Key = $advancedSettingName
            $opt.Value = $advancedSettingValue
            
            # Add the OptionValue object to the extraConfig array in the spec
            $spec.extraConfig += $opt
            
            # Apply the configuration change using ReconfigVM_Task
            $vmView.ReconfigVM_Task($spec) | Out-Null
            
            Write-Host " Success." -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host " FAILED. Error: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n--- Script Summary ---" -ForegroundColor Yellow
    Write-Host "Total VMs Processed: $($windowsVMs.Count)"
    Write-Host "Successfully Updated: $successCount" -ForegroundColor Green
    Write-Host "Failed Updates: $failCount" -ForegroundColor Red
    Write-Host "The change will take effect the next time the VM is powered on or rebooted." -ForegroundColor Cyan

}
catch {
    Write-Error "An unexpected error occurred during VM processing: $($_.Exception.Message)"
}
finally {
    # 3. Disconnect from vCenter
    Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
    Disconnect-VIServer -Confirm:$false
}