<#
.SYNOPSIS
Configures file server features, directories, permissions, and SMB shares.
.DESCRIPTION
This script automates the setup of a Windows File Server based on JSON input. It enables the file server role,
configures folder structures, applies ACLs, and sets up SMB shares according to a security model.
.PARAMETER inputFile
Path to the input JSON file containing configuration parameters.
.EXAMPLE
.\fileserver_b.ps1 -inputFile "C:\config\fileServerConfig.json"
.NOTES
Author:
Version: 1.0
#>
param(
[Parameter(Mandatory = $true)]
[string]$inputFile
)
# Define log file
$logPath = "C:\Logs\FileServerSetup.log"
try {
New-Item -Path (Split-Path $logPath) -ItemType Directory -Force | Out-Null
} catch {
Write-Host "Failed to create log directory: $_"
exit 1
}

function Write-Log {
 param (
 [string]$message,
 [string]$type = "INFO"
 )
 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 $logMessage = "$timestamp [$type] $message"
 Write-host $logMessage
 Add-Content -Path $logPath -Value $logMessage 
} 

function Get-FeatureState($featureName) {
try {
$feature = Get-WindowsFeature -Name $featureName
return $feature.Installed
} catch {
Write-Log "Failed to get feature state for '$featureName'. $_" "ERROR"
return $false
}
}
function Install-FSFeature($featureList) {
foreach ($feature in $featureList) {
if (-not (Get-FeatureState $feature)) {
try {
Install-WindowsFeature -Name $feature -IncludeAllSubFeature -ErrorAction Stop
Write-Log "Successfully installed: $feature"
} catch {
Write-Log "Failed to install feature '$feature'. $_" "ERROR"
}
} else {
Write-Log "Feature already installed: $feature"
}
}
}

try {
$config = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
Write-Log "Configuration file loaded from $inputFile"
} catch {
Write-Log "Failed to read or parse configuration file: $_" "ERROR"
exit 1
}

$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".", 2)[0]
$domain = $fqdn.Split(".", 2)[1]
if(!$domain){
Write-Log "Failed to retrieve FQDN or domain. $_" "ERROR"
exit 1
}


if (-not $config.existing_fileserver) {

Write-Log "Starting File Server Configuration."
# Import configuration

$features = $config.features
# Enable File Server Feature
if ($features.length -gt 0) {
Install-FSFeature $features
Write-Log "File Server feature installation logic complete."
}
# Extract domain
$fs_domain = $domain

foreach ($drive in (Get-WmiObject -Query "select * from win32_logicaldisk" )) {
$letter = $drive.DeviceID -replace ":", ""
$details = if ($drive.DriveType -eq 3) { "Fixed" } else { "External" }
if ($details -eq "Fixed" -and $letter -ne 'C' -and $letter -ne 'D') {write-host "-----------------------------------------------------------------"
$drive
Write-Host "Condition met" -ForegroundColor Green
write-host "-----------------------------------------------------------------"

$sharedDataPath = "$($letter):\SharedData"
$usersPath = "$($letter):\Users"
if (-not (Test-Path $sharedDataPath)) {
try {
New-Item -Path $sharedDataPath -ItemType Directory -Force | Out-Null
Write-Log "Created directory: $sharedDataPath"
} catch {
Write-Log "Directory creation failed on $sharedDataPath $sharedDataPath $_" "ERROR"
continue
}
} else {
Write-Log "Directory $sharedDataPath already exists"
}
if (-not (Test-Path $usersPath)) {
try {
New-Item -Path $usersPath -ItemType Directory -Force | Out-Null
Write-Log "Created directory: $usersPath"
} catch {
Write-Log "Directory creation failed on $usersPath $usersPath $_" "ERROR"
continue
}
} else {
Write-Log "Directory $usersPath already exists"
}
try {
$aclUsers = Get-Acl $usersPath
$aclShared = Get-Acl $sharedDataPath
} catch {
Write-Log "Failed to get ACLs on $letter : $_" "ERROR"
continue
}
$identities = @(
"${fs_domain}\DATAFULL.LG",
"${fs_domain}\DATALIST.LG",
"${fs_domain}\DATAWRITE.LG",
"${fs_domain}\DataRead.LG",
"BUILTIN\Administrators",
"SYSTEM"
)
$rightsMap = @{
"${fs_domain}\DATAFULL.LG" = 'FullControl'
"${fs_domain}\DATALIST.LG" = 'ReadAndExecute'
"${fs_domain}\DATAWRITE.LG" = 'Modify'
"${fs_domain}\DataRead.LG" = 'ReadAndExecute'
"BUILTIN\Administrators" = 'FullControl'
"SYSTEM" = 'FullControl'
}
foreach ($id in $identities) {#if($id -match "\"){$i=($id.Split("\")[1])}else {$i=$id}
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
$id,
$rightsMap[$id],
"ContainerInherit,ObjectInherit",
"None",
"Allow"
)
$aclUsers.SetAccessRule($rule)
$aclShared.SetAccessRule($rule)
}
try {
Set-Acl -Path $usersPath -AclObject $aclUsers
Write-Log "ACLs applied to $usersPath."
} catch {
Write-Log "Failed to apply ACLs on $letter $usersPath $_" "ERROR"
}
try {
Set-Acl -Path $sharedDataPath -AclObject $aclShared
Write-Log "ACLs applied to $sharedDataPath."
} catch {
Write-Log "Failed to apply ACLs on $letter $sharedDataPath $_" "ERROR"
}
try {
New-SmbShare -Name "Users$letter" -Path $usersPath -FullAccess "${fs_domain}\DATAFULL.LG","${fs_domain}\DATAWRITE.LG" -ChangeAccess "Authenticated Users" -ReadAccess "${fs_domain}\DataRead.LG" -ErrorAction Stop
#New-SmbShare -Name "Users$letter" -Path $usersPath -FullAccess "DATAFULL.LG","DATAWRITE.LG" -ChangeAccess "Authenticated Users" -ReadAccess "DataRead.LG" -ErrorAction Stop
Write-Log "SMB Share created for $usersPath."
} catch {
Write-Log "Failed to create SMB Share for $letter $usersPath $_" "ERROR"
}
try {
New-SmbShare -Name "SharedData$letter" -Path $sharedDataPath -FullAccess "${fs_domain}\DATAFULL.LG","${fs_domain}\DATAWRITE.LG" -ReadAccess "${fs_domain}\DataRead.LG" -ErrorAction Stop
#New-SmbShare -Name "SharedData$letter" -Path $sharedDataPath -FullAccess "DATAFULL.LG","DATAWRITE.LG" -ReadAccess "DataRead.LG" -ErrorAction Stop
Write-Log "SMB Share created for $sharedDataPath."
} catch {
Write-Log "Failed to create SMB Share for $letter $sharedDataPath $_" "ERROR"
}
}
else{write-host "-----------------------------------------------------------------"
$drive
write-host "Condition not met" -ForegroundColor Red}
write-host "-----------------------------------------------------------------"
}
 
Write-Log "File Server Configuration completed successfully."
}else {
Write-Log "Configuration skipped: existing file server."
}