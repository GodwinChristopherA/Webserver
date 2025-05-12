<#
.SYNOPSIS
Create directories and sets NTFS permissions based on a JSON configuration file.
.DESCRIPTION
This script reads a JSON configuration file to create directories and set NTFS permissions.
It logs the operations and any error that occur during execution.
.PARAMETER ConfigPath
Path to the jSON Configuration file containing directory and permissions information.
Defaults to ".\directory.json" if not specified.
.EXAMPLE
.\directories_1.ps1 -ConfigPath ".\directory.json"
This will create directories and set permissions as specified in the 'directory.json' file.
.NOTES
Author:Diksha Goyal
Requires: PowerShell 5.1 or higher, appropriate NTFS permissions to create directories and modify ACLs.
.VERSION
1.0
#>
param (
[Parameter(Mandatory = $true)]
[string]$ConfigPath = ".\directory.json"
)
 
# Load configuration
$config = Get-Content -Path $ConfigPath -Raw| ConvertFrom-Json
 
# Logging function
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "directories.log"
function Write-Log {
param (
[string]$message,
[string]$type = "INFO"
)
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logMessage = "$timestamp [$type] $message"
Add-Content -Path $logPath -Value $logMessage
}
# Set NTFS permissions
function Add-Permission {
param (
[string]$Path,
[string]$Identity,
[string[]]$Rights,
[switch]$RemoveExisting
)
if (-not (Test-Path $path)) {
try {
New-Item -ItemType Directory -Path $path -Force | Out-Null
} catch {
Write-Log "Failed to create directory: $path - $_" "ERROR"
break
}
} else {
Write-Log "Directory $path exists"
}
 
try {
$acl = Get-Acl $Path
if ($RemoveExisting) {
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
} if($Identity){
$rightsEnum = [System.Security.AccessControl.FileSystemRights]::None
foreach ($right in $Rights) {
$rightsEnum = $rightsEnum -bor [System.Security.AccessControl.FileSystemRights]::$right
}
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $rightsEnum, "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path $Path -AclObject $acl
} }catch {
Write-Log "Failed to set permissions for $Path - $_" "ERROR"
}
}

 
foreach ($perm in $config.directories) {
Add-Permission -Path $perm.Path -Identity $perm.Identity -Rights $perm.Rights @($perm.RemoveExisting)
}