$VMs = Get-Content "\\groupfiles\wits\tzjensen\Vmware_Tools_Upgrade.txt"
$Toolsconfig = New-Object VMware.Vim.VirtualMachineConfigSpec
$Toolsconfig.tools = New-Object VMware.Vim.ToolsConfigInfo
$Toolsconfig.tools.toolsUpgradePolicy = "upgradeAtPowerCycle"

foreach ($VM in $VMs) {
Write-Warning "Setting VM Tools to Upgrade on PowerOn for $VM"
(Get-VM -Name $VM | Get-View).ReconfigVM($Toolsconfig)
}