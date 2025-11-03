#TaskbarAl
$taskbarAl = 0000000
$regpath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
New-ItemProperty -Path "$regpath" -Name "TaskbarAl" -Value "$taskbarAl"  -PropertyType "DWORD" -Force
