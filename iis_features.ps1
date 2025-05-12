<#
.SYNOPSIS
Automates the installation and configuration of IIS features on a Windows Server.
 
.DESCRIPTION
This script installs necessary IIS features, handles legacy .NET 3.5 features,
and optionally adjusts based on DMZ or Server Core environments.
It includes error handling for each operation to ensure robust execution.
Configuration is supplied via a JSON file.
 
.PARAMETER ConfigFile
The path to the JSON configuration file specifying features to install or remove.
 
.EXAMPLE
.\iis_features_7.ps1 -ConfigFile "C:\iis_config_features.json"
 
.NOTES
Ensure you run the script with administrative privileges.
The script logs installation actions to `iis_features.log` in the script root.
Author: Diksha Goyal
 
.VERSION
1.0
#>
 
param (
 [Parameter(Mandatory = $true)]
 [string]$ConfigFile
)
 
# Load configuration
$config = Get-Content -Path $ConfigFile | ConvertFrom-Json
 
$features = $config.features
$features_legacy = $config.features_legacy
$is_dmz = $config.is_dmz
$is_server_core = $config.is_server_core
 
# Define log file path
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "iis_features.log"
 
# Function to write log
function Write-Log {
 param (
 [string]$message,
 [string]$type = "INFO"
 )
 $timestamp = Get-Date -Format "yyyy-MM-dd HH::mm::ss"
 $logMessage = "$timestamp [$type] $message"
 Write-Output $logMessage
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
 
function Install-IISFeature($featureList) {
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
 
function Remove-IISFeature($featureList) {
 foreach ($feature in $featureList) {
 if (Get-FeatureState $feature) {
 try {
 Remove-WindowsFeature -Name $feature -ErrorAction Stop
 Write-Log "Successfully removed: $feature"
 } catch {
 Write-Log "Failed to remove feature '$feature'. $_" "ERROR"
 }
 }
 }
}
<# Check DMZ and adjust accordingly
$additional_features = if ($is_dmz) {
 @('Web-Http-Redirect', 'Web-Mgmt-Service', 'Web-Scripting-Tools')
} else {
 @()
}
 
# Combine and install
$total_feature_list = $features + $additional_features
if($total_feature_list.length -gt 0){
Install-IISFeature $total_feature_list} #>
if($features.length -gt 0){
Install-IISFeature $features}
 Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools
# Install legacy .NET 3.5 features
if ($features_legacy.Length -gt 0) {
 try {
 #call .dotnet.ps1 for for instaling dotnet 3.5
 Powershell.exe "./dotnet_main.ps1" 
 } catch {
 Write-Log "Failed to install legacy .NET 3.5 features. $_" "ERROR"
 }
}
 
#Remove specific features if in DMZ
$features_to_disable = @('Web-Dir-Browsing')
 
Remove-IISFeature $features_to_disable 
 
# Install additional if not server core
if (-not $is_server_core) {
 Install-IISFeature @('Web-Mgmt-Console')
}
 
Write-Log "IIS Configuration Completed."
 