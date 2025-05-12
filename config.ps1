<#
.SYNOPSIS
 Configures IIS with logging, website, and app pool settings using DSC.
 
 .DESCRIPTION
 This script sets up IIS configuration.
 - Setting up directories and applying default ASP.NET configurations.
 - Enabling logging and error tracing.
 - Optionally configuring application pool defaults.
 
 .EXAMPLE
 .\Config_3.ps1 
 
.NOTES
 Author: Diksha Goyal
 
.VERSION
 1.0
#>
 
param (
 [string]$log_directory = 'C:\WebServer\E\IIS\logs\logFiles',
 [string]$trace_log_directory = 'C:\WebServer\E\IIS\logs\FailedReqLogFiles',
 [string]$dotnet_directory = 'C:\Windows\Microsoft.NET'
 )
<#
$fqdn = [System.Net.Dns]::GetHostEntry((HostName)).HostName
$hostname = $fqdn.Split(".",2)[0]
$domain = $fqdn.Split(".",2)[1]
$srvload_path = "\\$domain\dfs\srvload"
#>
$srvload_path = "C:\WebServer\SRVloadpath"
# Define log file path
$logPath = Join-Path -Path $PSScriptRoo -ChildPath "Config.log"
 
# Function to write to log
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
 
 
 configuration IISXOMConfiguration {

    param (
        [string]$log_directory,
        [string]$trace_log_directory,
        [string]$srvload_path,
        [string]$dotnet_directory = 'C:\Windows\Microsoft.NET'
        )
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xWebAdministration'


    $asp_x64_40_directory = Join-Path $dotnet_directory 'Framework64\v4.0.30319'
    $asp_x86_40_directory = Join-Path $dotnet_directory 'Framework\v4.0.30319'

    Node localhost {
        File AspNetConfigX64 {
            DestinationPath = Join-Path $asp_x64_40_directory 'aspnet.config'
            Type = 'File'
            Ensure = 'Present'
            SourcePath = Join-Path $srvload_path 'IIS8\XOMStandardLoads\Aspnet_x64_4.0.config'
            Force = $true
        }

        File AspNetConfigX86 {
            DestinationPath = Join-Path $asp_x86_40_directory 'aspnet.config'
            Type = 'File'
            Ensure = 'Present'
            SourcePath = Join-Path $srvload_path 'IIS8\XOMStandardLoads\Aspnet_x86_4.0.config'
            Force = $true
        }

        xIISLogging 'XOM_IIS_Logging' {
            LogPath = $log_directory
            LogFormat = 'W3C'
            LogFlags = @(
                'Date','Time','ClientIP','UserName','ServerIP','Method','UriStem','UriQuery',
                'HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort',
                'ProtocolVersion','UserAgent','HttpSubStatus'
            )
        }

        xWebsiteDefaults 'XOM_IIS_Website_Defaults' {
            IsSingleInstance = 'Yes'
            LogFormat = 'W3C'
            LogDirectory = $log_directory
            TraceLogDirectory = $trace_log_directory
        }

        # Optionally enable app pool settings
        <#
        xWebAppPoolDefaults 'XOM_IIS_App_Pool_Defaults' {
            ApplyTo = 'Machine'
            ManagedRuntimeVersion = 'v4.0'
        }
        Write-log "Failed to configure AppPool defaults: $_"
        #>
    }
}
try {

IISXOMConfiguration -log_directory $log_directory -srvload_path $srvload_path -dotnet_directory $dotnet_directory -trace_log_directory $trace_log_directory
Start-DscConfiguration -Path .\IISXOMConfiguration -Wait -Force -Verbose
}
catch {
Write-log " Failed to configure "
}
 