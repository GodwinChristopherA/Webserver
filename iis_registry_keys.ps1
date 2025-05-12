<#
.SYNOPSIS
 Sets the MaxSize registry value for specified Event Viewer logs.
 
.DESCRIPTION
 This script reads a JSON input file that contains a list of registry paths,
 then applies the MaxSize setting to each specified registry key.
 
.PARAMETER InputFile
 Path to the JSON file containing registry keys.
 
 
.EXAMPLE
 .\iis_registry_keys.ps1 -InputFile ".\registry_settings.json" 
 
.NOTES
 Ensure the script is run with administrative privileges to modify the registry.
 Author: Diksha Goyal
 
.VERSION
 1.0
#>
 
param (
 [Parameter(Mandatory = $true)]
 [string]$InputFile
 )
 
# Define log file path
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "registry_keys.log"
 
# Function to write log
function Write-Log {
 param (
 [string]$message,
 [string]$type = "INFO"
 )
 $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 $logMessage = "$timestamp [$type] $message"
 Write-Output $logMessage
 Add-Content -Path $logPath -Value $logMessage
}
 
# Read and parse the JSON input file
try {
 $config = Get-Content -Path $InputFile | ConvertFrom-Json
 $eventViewerLogs = $config.EventViewerLogs
 }
catch {
 Write-Log "Failed to read or parse JSON input file: $InputFile. Error: $_" "ERROR"
 exit 1
}
 $maxSize = "0x05000000"
# Apply the registry changes
foreach ($key in $eventViewerLogs) {
 try {
 Set-ItemProperty -Path $key -Name 'MaxSize' -Value $maxSize -Type DWord
 Write-Log "Set MaxSize for $key successfully."
 }
 catch {
 Write-Log "Failed to set MaxSize for $key. Error: $_" "ERROR"
 }
}
 