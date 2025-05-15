<#
.SYNOPSIS
One-time IIS server configuration and setup script for Windows environments.
.DESCRIPTION
This script configures IIS by deploying custom error pages, setting registry paths,
creating SMB shares, updating scheduled tasks, and moving default content to the E: drive.
It includes environment-specific behavior for DMZ configurations and sets up autoload registry keys.
.PARAMETER srvload_path
Path to the source load directory for IIS content and configurations.
.PARAMETER log_tool_dir
Path to the directory containing the IIS log maintenance script.
.EXAMPLE
.\webserverftp_oneconfig.ps1 -srvload_path "C:"
.NOTES
- Requires Administrator privileges.
- Ensure E:\ drive exists before running.
.VERSION
1.0.0
#>
param (
#[Parameter(Mandatory = $true)]
[string]$log_tool_dir="e:\IIS_LOG_TOOL"
)
$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".",2)[0]
$domain = $fqdn.Split(".",2)[1]
#$srvload_path = "\\$domain\dfs\srvload"
$srvload_path = "C:\WebServer\SRVloadpath"
# Define log file
$logFile = "C:\temp\IIS_OneTimeConfig.log"
try {
New-Item -Path (Split-Path $logFile) -ItemType Directory -Force | Out-Null
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
 Add-Content -Path $logFile -Value $logMessage 
} 
# Create directory and copy custom error pages
Write-Log "START: Creating custom error directory and copying base pages"
if (-not (Test-Path 'C:\inetpub\custerr\en-US' )) {
try {
New-Item -ItemType Directory -Path 'C:\inetpub\custerr\en-US' -Force | Out-Null
} catch {
Write-Log "Failed to create directory: $path - $_" "ERROR"
break
}
} else {
Write-Log "Directory $path exists"
}
Copy-Item "$srvload_path\IIS8\XOMStandardLoads\htmlhelp\*" 'C:\inetpub\custerr\en-US' -Recurse -Exclude '404.htm', '404.HTM', '500-100.asp' -Force
Write-Log "SUCCESS: Custom error directory created and pages copied"
# Copy custom 404 page
try {
Write-Log "START: Copying custom 404 error page"
Copy-Item "$srvload_path\IIS8\XOMStandardLoads\CUSTOMERRORPAGES\404.htm" 'C:\inetpub\custerr\en-US\404.htm' -Force
Write-Log "SUCCESS: Custom 404 error page copied"
} catch {
Write-Log "ERROR: $_"
}
# Create IIS log SMB share
try {
Write-Log "START: Creating IIS log SMB share"
$sharePath = 'e:\IIS\logs'
New-Item -Path $sharePath -ItemType Directory -Force | Out-Null
New-SmbShare -Name 'Logs$' -Path $sharePath -Description 'IIS Log Share' -FullAccess 'Authenticated Users'
Enable-BCHostedCache -Force
Write-Log "SUCCESS: SMB share and BranchCache configured"
} catch {
Write-Log "ERROR: $_"
}
# Schedule IIS log tool
try {
Write-Log "START: Creating scheduled task for IIS log maintenance"
$taskName = 'Run IIS_LOG_TOOL Every Night'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-nologo -file `"$log_tool_dir\IISLogsMaintenance.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 22:00
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force
Write-Log "SUCCESS: Scheduled task created"
} catch {
Write-Log "ERROR: $_"
}
# DMZ check
$is_dmz = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain -match 'dmz'
Write-Log "DMZ Check: is_dmz = $is_dmz"
# Stop IIS if e:\inetpub does not exist
if (!(Test-Path 'e:\inetpub')) {
try {
Write-Log "START: Stopping IIS services"
iisreset /stop
Write-Log "SUCCESS: IIS stopped"
} catch {
Write-Log "ERROR: $_"
}
}
# Copy inetpub content
try {
Write-Log "START: Copying inetpub content to E drive"
if (!(Test-Path 'e:\inetpub')) {
Start-Process -FilePath 'xcopy.exe' -ArgumentList 'C:\inetpub e:\inetpub /E /O /I /Y' -Wait
}
Write-Log "SUCCESS: inetpub content copied"
} catch {
Write-Log "ERROR: $_"
}
# Update wwwroot registry keys
try {
Write-Log "START: Updating wwwroot registry paths"
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\inetstp' -Name 'PathWWWRoot' -Value 'e:\inetpub\wwwroot'
Set-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Microsoft\inetstp' -Name 'PathWWWRoot' -Value 'e:\inetpub\wwwroot'
Write-Log "SUCCESS: Registry keys updated"
} catch {
Write-Log "ERROR: $_"
}
# Create AppPool directories
try {
Write-Log "START: Creating AppPool temp directories"
@('e:\inetpub\temp', 'e:\inetpub\temp\appPools') | ForEach-Object {
New-Item -Path $_ -ItemType Directory -Force | Out-Null
}
Write-Log "SUCCESS: AppPool directories created"
} catch {
Write-Log "ERROR: $_"
}
# Set AppPool config isolation path
try {
Write-Log "START: Setting AppPool ConfigIsolationPath registry value"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\WAS\Parameters' -Name 'ConfigIsolationPath' -Value 'e:\inetpub\temp\appPools'
Write-Log "SUCCESS: ConfigIsolationPath set"
} catch {
Write-Log "ERROR: $_"
}
# Start IIS services
try {
Write-Log "START: Starting WAS and W3SVC services"
Set-Service -Name 'WAS' -StartupType Automatic
Start-Service -Name 'WAS'
Set-Service -Name 'W3SVC' -StartupType Automatic
Start-Service -Name 'W3SVC'
Write-Log "SUCCESS: WAS and W3SVC services running"
} catch {
Write-Log "ERROR: $_"
}
# Simulate applying IIS properties
Write-Log "INFO: Applying IIS properties (simulated)"
# Set Exxon autoload registry key
try {
Write-Log "START: Setting Exxon autoload registry key"
$autoloadKey = if ($is_dmz) {
'HKLM:\SOFTWARE\ExxonMobil\Autoload\Phase3\IIS 10 Internet Server Installation'
} else {
'HKLM:\SOFTWARE\ExxonMobil\Autoload\Phase3\IIS 10 Intranet Server Installation'
}
New-Item -Path $autoloadKey -Force | Out-Null
Set-ItemProperty -Path $autoloadKey -Name 'Installed' -Value '1'
Write-Log "SUCCESS: Exxon autoload key set"
} catch {
Write-Log "ERROR: $_"
}
Write-Log "IIS one-time configuration script completed."