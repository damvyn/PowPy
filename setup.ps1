<#
 .Synopsis
   Short description
 .DESCRIPTION
   Long description
 .EXAMPLE
   Example of how to use this cmdlet
 .EXAMPLE
   Another example of how to use this cmdlet
 .INPUTS
   Inputs to this cmdlet (if any)
 .OUTPUTS
   Output from this cmdlet (if any)
 .NOTES
   General notes
 .COMPONENT
   The component this cmdlet belongs to
 .ROLE
   The role this cmdlet belongs to
 .FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
[CmdletBinding()]
param()


function Download-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -ErrorAction Stop
        Write-Host "Downloaded file from $Url to $DestinationPath"
    } catch {
        Write-Error "Failed to download file from $Url. Error: $_"
    }
}


$TargetDir = Read-Host -Prompt "Enter ProjectTarget Directory. Press Enter for C:\PowPuLa"
If ([string]::IsNullOrEmpty($TargetDir)) { $TargetDir = "C:\PowPuLa" }
$null = New-Item -Path $TargetDir -ItemType Directory -Force


$PyVer = Read-Host -Prompt "Enter Python Version. Press Enter for latest"
If ([string]::IsNullOrEmpty($PyVer)) { $PyVer = "Latest" }

#region download Python
# get Python versions from the official Python api
$BaseUrl = 'https://www.python.org/api/v2/downloads/release/?is_published=true'

$VersUrl = if ($PyVer -eq 'Latest') { 
    $BaseUrl + '&is_latest=true&pre_release=false&version=3'
} else { $BaseUrl + "&pre_release=false&name=Python+$PyVer" }

Write-Host "Fetching version information from $VersUrl"
$versionData = Invoke-RestMethod -Uri $VersUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

# detect the desired version is present
$WantedVersion = $versionData |
    Sort-Object {$_.name.Replace("Python ", "") -as [version]} |
    Select-Object -Last 1

If (-not $WantedVersion) {
    Write-Host "No matching Python version found for '$PyVer'." -ForegroundColor Red
    return
} else {Write-Host "Found version $($WantedVersion.name)"}
#endregion download Python



