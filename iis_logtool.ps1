<#
.SYNOPSIS
Sets up the IIS_LOG_TOOL directory with test data and applies appropriate ACL permissions.
 
.DESCRIPTION
This script simulates copying IIS log tool files
from a source directory to a destination. It ensures both directories exist, copies files,
and sets ACL permissions for "Administrators" and "SYSTEM" with full control. Includes
error handling and logging.
 
 
.EXAMPLE
.\iis_log_tool_4.ps1
 
.NOTES
Author: Diksha Goyal
Version: 1.0
 
#>
 
param (
[string]$log_tool_dir = 'c:\Webserver\e\IIS_LOG_TOOL'
)
 

 <#
$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".",2)[0]
$domain = $fqdn.Split(".",2)[1]

$srvload_path="\\$domain\dfs\srvload"
#>
$srvload_path="C:\WebServer\SRVloadpath"
# Logging
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "iis_logtool.log"
function Write-Log {
param (
[string]$message,
[string]$type = "INFO"
)
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logMessage = "$timestamp [$Node] [$type] $message"
Write-Output $logMessage
Add-Content -Path $logPath -Value $logMessage
}
$source_path ="${srvload_path}\\IIS8\\XOMStandardLoads\\IIS_LOG_TOOL"
 
# Create dummy source dir if missing
if (-not (Test-Path $source_path)) {
try {
Write-Log "Creating dummy source path: $source_path"
New-Item -ItemType Directory -Path $source_path -Force | Out-Null
New-Item -ItemType File -Path "$source_path\dummy.txt" -Force | Out-Null
} catch {
Write-Log "Failed to create source path: $_" "ERROR"
break
}
}
 
# Ensure destination exists
if (-not (Test-Path $log_tool_dir)) {
try {
Write-Log "Creating destination path: $log_tool_dir"
New-Item -ItemType Directory -Path $log_tool_dir -Force | Out-Null
} catch {
Write-Log "Failed to create destination path: $_" "ERROR"
break
}
} else {
Write-Log "Destination already exists: $log_tool_dir"
}
 
# Copy files
try {
Write-Log "Copying files from $source_path to $log_tool_dir"
Copy-Item -Path "$source_path\*" -Destination $log_tool_dir -Recurse -Force
Write-Log "Files copied successfully."
} catch {
Write-Log "File copy failed: $_" "ERROR"
break
}
 
# Set ACL
function Set-IISLogToolAcl {
param (
[string]$targetDir
)
try {
$acl = Get-Acl -Path $targetDir
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
"Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
"SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($adminRule)
$acl.SetAccessRule($systemRule)
Set-Acl -Path $targetDir -AclObject $acl
Write-Log "Permissions set successfully on $targetDir"
} catch {
Write-Log "Failed to set permissions: $_" "ERROR"
}
}
 
Write-Log "Setting ACL permissions..."
Set-IISLogToolAcl -targetDir $log_tool_dir