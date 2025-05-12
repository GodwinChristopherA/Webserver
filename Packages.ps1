<#
.SYNOPSIS
Installs the IIS URL Rewrite Module if it is not already installed on the system.
 
.DESCRIPTION
It checks whether the IIS URL Rewrite Module is already installed, and if not, installs it silently using msiexec.
Post installation, it verifies the installation.
 
.PARAMETER InputFile
Path containing installation configuration values:
- srvload_path
 
.EXAMPLE
.\packages_2.ps1 -srvload_path "\\sharepath\folder\" -restartserver
 
.NOTES
Author: Diksha Goyal
 
.VERSION
1.0
#>
param(
[switch]$restartserver = $false
)
<#
$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".",2)[0]
$domain = $fqdn.Split(".",2)[1]
$srvload_path = "\\$domain\dfs\srvload"
#>
 $srvload_path = "C:\WebServer\SRVloadpath"
 
# Define the source of the installer
$installerPath = "$srvload_path\IIS10\rewrite_amd64.msi"
#define log file path
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "packages.log"
#Function to write log
function Write-Log {
param (
[string]$message,
[string]$type = "INFO"
)
$timestamp = Get-Date -Format "yyyy-MM-dd HH::mm::ss"
$logMessage = "$timestamp [$type] $message"
Write-host $logMessage
Add-Content -Path $logPath -Value $logMessage
}
 
# Check if the URL Rewrite module is already installed
$packageName = "IIS URL Rewrite Module 2"
$installed = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = '$packageName'" -ErrorAction Stop
 
if (-not $installed) {
Write-log "Installing $packageName..."
 
try {
# Install the package silently
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /quiet /qn" -NoNewWindow -Wait -ErrorAction Stop
}
catch {
Write-log "Error occurred during installation: "
$_ | Out-File $logPath -Append
}
 
# Verify if installation was successful
$installed = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = '$packageName'" -ErrorAction Stop
 
if ($installed) {
Write-log "$packageName installed successfully."
if($restartserver){
Write-log "Rebooting the System..."
Restart-Computer -Force}
} else {
Write-log "Installation Failed."
}
}
else {
Write-log "$packageName is already installed."
}