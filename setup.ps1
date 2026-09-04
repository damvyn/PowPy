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
        $FileName = Split-Path -Path $Url -Leaf
        $FilePath = "$DestinationPath\$FileName"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $FilePath -ErrorAction Stop
        Write-Host "$FilePath was downloaded."
        return $FilePath
    } catch { Write-Error "Failed to download file from $Url. Error: $($_.Exception.Message)" }
}

$RootPath = Read-Host -Prompt "Enter directory path. Press Enter for C:\PowPy"
If ([string]::IsNullOrEmpty($RootPath)) { 
    $RootPath = "C:\PowPy"
    Write-Host "`tSelected path: $RootPath" -foregroundcolor green
}
$null = New-Item -Path $RootPath -ItemType Directory -Force


#region download Python
$PyVer = Read-Host -Prompt "Enter Python Version. Press Enter for latest"
If ([string]::IsNullOrEmpty($PyVer)) { 
    $PyVer = "Latest"
    Write-Host "`tSelected Python version: $PyVer" -foregroundcolor green
}

# get Python versions from the official Python api
$PyBaseUrl = 'https://www.python.org/api/v2/downloads/release/?is_published=true'
$PyVersUrl = if ($PyVer -eq 'Latest') { 
    $PyBaseUrl + '&is_latest=true&pre_release=false&version=3'
} else { $PyBaseUrl + "&pre_release=false&name=Python+$PyVer" }

$versionData = Invoke-RestMethod -Uri $PyVersUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

# detect the desired version is present
$WantedVersion = $versionData |
    Sort-Object {$_.name.Replace("Python ", "") -as [version]} |
    Select-Object -Last 1

If (-not $WantedVersion) {
    Write-Host "No matching Python version found for '$PyVer'." -ForegroundColor Red
    return
} else {Write-Host "Download Python $($WantedVersion.name)..."}

# get download link for the desired version
$PyDownloadUrl = 'https://www.python.org/api/v2/downloads/release_file/'
$PyDownloadData = Invoke-RestMethod -Uri $PyDownloadUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

$Release = $WantedVersion.resource_uri
$rname = Read-Host -Prompt "Clarify architecture (64, 32, arm64). Press Enter for 64-bit"
switch ($rname) {
    '32' { $ReleaseName = 'Windows embeddable package (32-bit)' }
    'arm64' { $ReleaseName = 'Windows embeddable package (ARM64)' }
    default { 
        $ReleaseName = 'Windows embeddable package (64-bit)'
        Write-Host "`tSelected architecture: 64-bit" -foregroundcolor green
    }
}

if (-not $ReleaseName) {
    Write-Host "No matching architecture found for '$rname'." -ForegroundColor Red
    return
}

$DownloadUrl = ($PyDownloadData | Where-Object {$_.release -eq $Release -and $_.name -eq $ReleaseName}).url
$PyFile = Download-File -Url $DownloadUrl -DestinationPath $RootPath
#endregion download Python


#region extract Python
Write-Host "Extract Python..."
$PyDir = Join-Path -Path $RootPath -ChildPath "Python"
$null = New-Item -Path $PyDir -ItemType Directory -Force
Expand-Archive -Path $PyFile -DestinationPath $PyDir -Force
Remove-Item -Path $PyFile -Force
#endregion extract Python


#region setup python
Write-Host "Set-up Python..."
$PyPth = get-Item -path $RootPath\Python\*._pth
If ($PyPth) {
    Write-Host "Setting up Python..."
    (Get-Content -Path $PyPth.FullName).Replace('#import site', 'import site') |
    Set-Content -Path $PyPth.FullName
}
#endregion setup python


#region download  pip
Write-Host "Download pip..."
$PipInstaller = Download-File -Url 'https://bootstrap.pypa.io/get-pip.py'  -DestinationPath $RootPath\Python
&"$RootPath\Python\Python.exe" "$PipInstaller" --quiet --no-warn-script-location
&"$RootPath\Python\Python.exe" -m pip install encoding-tools --quiet --no-warn-script-location
$null = New-Item -Path "$RootPath\Python\DLLs" -ItemType Directory -Force
#endregion download pip


#region download git
Write-Host "Download Git..."
$GitUrl = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
$GitReleaseData = Invoke-RestMethod -Uri $GitUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop
$gitPattern = if ($rname -eq 'arm64') { 'PortableGit**ARM64*.7z.exe' } else { 'PortableGit**64*bit*.7z.exe' }
$GitDownloadUrl = ($GitReleaseData.assets | Where-Object {$_.name -like $gitPattern}).browser_download_url
$null = New-Item -Path "$RootPath\Git" -ItemType Directory -Force
$GitFile = Download-File -Url $GitDownloadUrl -DestinationPath $RootPath
#endregion download git


#region extract git
Write-Host "Extract Git..."
$GitDir = Join-Path -Path $RootPath -ChildPath "Git"
$null = New-Item -Path $GitDir -ItemType Directory -Force
Start-Process -FilePath $GitFile -ArgumentList "-o `"$GitDir`" -y" -Wait -WindowStyle 'Hidden'
Remove-Item -Path $GitFile -Force
#endregion extract git


#region clone git project
$GitRepoUrl = Read-Host -Prompt "Enter Git Repository URL (http)"
$RepoName = (Split-Path -Path $GitRepoUrl -Leaf).Replace('.git', '')
$RepoDir = "$RootPath\$RepoName"
$null = New-Item -Path $RepoDir -ItemType Directory -Force
$StartParams = @{
    'FilePath' = "$RootPath\Git\cmd\git.exe"
    'ArgumentList' = "clone $GitRepoUrl $RepoDir"
    'Wait' = $true
    'WindowStyle' = 'Hidden'
}
Start-Process @StartParams
Write-Host "Git repository cloned to $RepoDir."
Write-Host "Done! You can now run the project from $RepoDir."
pause