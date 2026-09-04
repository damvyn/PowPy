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

# $ProgressPreference = 'SilentlyContinue'

function Download-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        $FileName = Split-Path -Path $Url -Leaf
        $FilePath = "$DestinationPath\$FileName"
        Invoke-WebRequest -Uri $Url -OutFile $FilePath -ErrorAction Stop
        Write-Host "Downloaded file $FilePath"
        return $FilePath
    } catch {
        Write-Error "Failed to download file from $Url. Error: $_"
    }
}


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

# get download link for the desired version
$DownloadUrl = 'https://www.python.org/api/v2/downloads/release_file/'
$DownloadData = Invoke-RestMethod -Uri $DownloadUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

$Release = $WantedVersion.resource_uri
$rname = Read-Host -Prompt "Enter Release Name (64, 32, arm64). Press Enter for 64-bit"
switch ($rname) {
    '32' { $ReleaseName = 'Windows embeddable package (32-bit)' }
    'arm64' { $ReleaseName = 'Windows embeddable package (ARM64)' }
    default { $ReleaseName = 'Windows embeddable package (64-bit)' }
}
$DownloadUrl = ($DownloadData | Where-Object {$_.release -eq $Release -and $_.name -eq $ReleaseName}).url

$TargetDir = Read-Host -Prompt "Enter ProjectTarget Directory. Press Enter for C:\PowPyLa"
If ([string]::IsNullOrEmpty($TargetDir)) { $TargetDir = "C:\PowPyLa" }
$null = New-Item -Path $TargetDir -ItemType Directory -Force
$PyFile = Download-File -Url $DownloadUrl -DestinationPath $TargetDir
#endregion download Python