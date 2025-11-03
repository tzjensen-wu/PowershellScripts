Import-Module ActiveDirectory
$ADusername = ‘Summer2023’
$complist = Import-Csv -Path "C:\ProfileData\Desktop\computers.csv" | ForEach-Object {$_.NetBIOSName}
$comparray = $complist -join ","
Set-ADUser -Identity $ADusername -LogonWorkstations $comparray
Clear-Variable comparray