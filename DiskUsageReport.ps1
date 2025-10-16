# Caminho base dos perfis de utilizadores
$UserProfilesPath = "C:\Users"

# Obtém todos os diretórios de usuário
$UserDirs = Get-ChildItem $UserProfilesPath -Directory -ErrorAction SilentlyContinue

$Results = @()

foreach ($Dir in $UserDirs) {
    try {
        $Size = (Get-ChildItem $Dir.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $Results += [PSCustomObject]@{
            User  = $Dir.Name
            SizeGB = [Math]::Round($Size / 1GB, 2)
        }
    } catch {}
}

# Ordenar e obter o top 10
$Top10 = $Results | Sort-Object SizeGB -Descending | Select-Object -First 10

# Espaço total e livre no disco C:
$Disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$TotalGB = [Math]::Round($Disk.Size / 1GB, 2)
$FreeGB  = [Math]::Round($Disk.FreeSpace / 1GB, 2)

# Cria o relatório final
$Output = @{
    "Hostname" = $env:COMPUTERNAME
    "TotalGB"  = $TotalGB
    "FreeGB"   = $FreeGB
    "UsedGB"   = [Math]::Round(($TotalGB - $FreeGB), 2)
    "Top10Users" = $Top10
}

# Salva localmente (útil para debug)
$Output | ConvertTo-Json -Depth 4 | Out-File "C:\Scripts\DiskUsageReport.json"

# Envia para o Zabbix via sender
$ZabbixServer = "IP_DO_SEU_ZABBIX_SERVER"
$HostName = $env:COMPUTERNAME
$MetricKey = "custom.disk.usage"
$MetricValue = ($Output | ConvertTo-Json -Compress)
$TempFile = "C:\Scripts\zabbix_data.txt"
"$HostName $MetricKey $MetricValue" | Out-File $TempFile -Encoding ASCII
& "C:\Program Files\Zabbix Agent\zabbix_sender.exe" -z $ZabbixServer -i $TempFile | Out-Null
