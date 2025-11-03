##note: replace "username" and domain details
$Workstations = (Get-ADUser username -Properties LogonWorkstations).LogonWorkstations
$Workstations += ",username.domain.com"
Set-ADUser username -LogonWorkstations $Workstations