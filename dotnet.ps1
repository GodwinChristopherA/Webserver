<#
.SYNOPSIS
 Installs .NET Framework 3.5 on a Windows Server.
 
.DESCRIPTION
 This script installs the .NET Framework 3.5
 using a dynamically constructed source path based on the OS version. It also logs the
 installation status.
 
.EXAMPLE
 .\dotnet_6.ps1 
 
.NOTES
 Ensure the server path is accessible and the OS version directory structure matches.
 Author: Diksha Goyal
 
.VERSION
 1.0
#>
 

$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".",2)[0]
$domain = $fqdn.Split(".",2)[1]

$srvload_path="\\$domain\dfs\srvload"

 
# Define log file path
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "Dotnet.log"
# Function to write log
function Write-Log {
 param (
 [string]$message,
 [string]$type = "INFO"
 )
 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 $logMessage = "$timestamp [$type] $message"
 Add-Content -Path $logPath -Value $logMessage
}
 
# Define the source path based on OS version
$srvload_path = $config.srvload_path
$osVersion = (Get-CimInstance Win32_OperatingSystem).Version
$source = "$srvload_path\$osVersion\sxs"
 
try {
 # Install .NET Framework 3.5 feature
 Install-WindowsFeature -Name Net-Framework-Core -Source $source -IncludeAllSubFeature -ErrorAction Stop
 Write-Log ".NET Framework 3.5 installation completed successfully."
}
catch {
 Write-Log "Failed to install .NET Framework 3.5: $_" "ERROR"
}
 