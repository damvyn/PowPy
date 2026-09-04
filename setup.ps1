<#
.SYNOPSIS
    Sets up a local PowPy environment with Python, Git, and a project clone.

.DESCRIPTION
    Prompts for the installation directory and Python version, downloads the matching
    standalone Python package for the selected architecture, enables site packages,
    installs pip tooling, downloads portable Git, extracts it locally, and clones the
    target repository into the chosen PowPy folder.

.EXAMPLE
    .\setup.ps1

    Runs the interactive setup flow for creating a local PowPy workspace.

.NOTES
    Project: PowPy
    Platform: Windows
    Requires: PowerShell 5.1+, internet access, and a Git repository URL.
#>
[CmdletBinding()]
param(
    [string]$RootPath = '',
    [string]$PythonVersion = '',
    [string]$Architecture = '',
    [string]$RepoUrl = '',
    [switch]$SkipRepo,
    [switch]$Quiet
)

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

if ([string]::IsNullOrWhiteSpace($RootPath)) {
    if ($Quiet) {
        $RootPath = 'C:\PowPy'
    }
    else {
        $RootPath = Read-Host -Prompt "Enter directory path. Press Enter for C:\PowPy"
        if ([string]::IsNullOrWhiteSpace($RootPath)) { $RootPath = 'C:\PowPy' }
    }
    Write-Host "`tSelected path: $RootPath" -foregroundcolor green
}
$RootPath = $RootPath.TrimEnd("\\")
$null = New-Item -Path $RootPath -ItemType Directory -Force -ErrorAction Stop

#region download Python
if ([string]::IsNullOrWhiteSpace($PythonVersion)) {
    if ($Quiet) {
        $PyVer = 'Latest'
    }
    else {
        $PyVer = Read-Host -Prompt "Enter Python Version. Press Enter for latest"
        if ([string]::IsNullOrWhiteSpace($PyVer)) { $PyVer = 'Latest' }
    }
    Write-Host "`tSelected Python version: $PyVer" -foregroundcolor green
}
else {
    $PyVer = $PythonVersion
}
$PyVer = $PyVer.Trim()

# get Python versions from the official Python api
$PyBaseUrl = 'https://www.python.org/api/v2/downloads/release/?is_published=true'
$PyVersUrl = if ($PyVer -ieq 'Latest') {
    $PyBaseUrl + '&is_latest=true&pre_release=false&version=3'
} else {
    $PyBaseUrl + "&pre_release=false&name=Python+$PyVer"
}

$versionData = Invoke-RestMethod -Uri $PyVersUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

# detect the desired version is present
$WantedVersion = $versionData |
    Sort-Object { [version]($_.name -replace '^Python\s+', '') } |
    Select-Object -Last 1

If (-not $WantedVersion) {
    Write-Host "No matching Python version found for '$PyVer'." -ForegroundColor Red
    return
}
Write-Host "Download Python $($WantedVersion.name)..."

# get download link for the desired version
$PyDownloadUrl = 'https://www.python.org/api/v2/downloads/release_file/'
$PyDownloadData = Invoke-RestMethod -Uri $PyDownloadUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($Architecture)) {
    if ($Quiet) {
        $Arch = '64'
    }
    else {
        $Arch = Read-Host -Prompt "Clarify architecture (64, 32, arm64). Press Enter for 64-bit"
        if ([string]::IsNullOrWhiteSpace($Arch)) { $Arch = '64' }
    }
    Write-Host "`tSelected architecture: $Arch-bit" -foregroundcolor green
}
else {
    $Arch = $Architecture
}

switch ($Arch.Trim().ToLower()) {
    '32' { $ReleaseName = 'Windows embeddable package (32-bit)' }
    'arm64' { $ReleaseName = 'Windows embeddable package (ARM64)' }
    default { $ReleaseName = 'Windows embeddable package (64-bit)' }
}

$DownloadUrl = ($PyDownloadData | Where-Object {
    $_.release -eq $WantedVersion.resource_uri -and $_.name -eq $ReleaseName
}).url

if (-not $DownloadUrl) {
    Write-Host "No matching download found for Python '$($WantedVersion.name)' and architecture '$Arch'." -ForegroundColor Red
    return
}

$PyFile = Download-File -Url $DownloadUrl -DestinationPath $RootPath
#endregion download Python


#region extract Python
Write-Host "Extract Python..."
$PyDir = Join-Path -Path $RootPath -ChildPath "Python"
$null = New-Item -Path $PyDir -ItemType Directory -Force -ErrorAction Stop
Expand-Archive -Path $PyFile -DestinationPath $PyDir -Force -ErrorAction Stop
Remove-Item -Path $PyFile -Force -ErrorAction SilentlyContinue
#endregion extract Python

#region setup python
Write-Host "Set-up Python..."
$PythonExe = Get-ChildItem -Path $PyDir -Filter 'python.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $PythonExe) {
    Write-Host "Python executable was not found under $PyDir." -ForegroundColor Red
    return
}

$PyPth = Get-ChildItem -Path $PyDir -Filter '*.pth' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($PyPth) {
    Write-Host "Setting up Python site packages..."
    $PthContent = Get-Content -Path $PyPth.FullName -Raw
    if ($PthContent -notmatch 'import site') {
        $PthContent = $PthContent.Replace('#import site', 'import site')
        Set-Content -Path $PyPth.FullName -Value $PthContent
    }
}
#endregion setup python

#region download pip
Write-Host "Download pip..."
$PipInstaller = Download-File -Url 'https://bootstrap.pypa.io/get-pip.py' -DestinationPath $PyDir
& $PythonExe.FullName $PipInstaller --quiet --no-warn-script-location
& $PythonExe.FullName -m pip install --upgrade pip --quiet --no-warn-script-location
& $PythonExe.FullName -m pip install encoding-tools --quiet --no-warn-script-location
$null = New-Item -Path "$PyDir\DLLs" -ItemType Directory -Force -ErrorAction SilentlyContinue
#endregion download pip


#region download git
Write-Host "Download Git..."
$GitUrl = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
$GitReleaseData = Invoke-RestMethod -Uri $GitUrl -UseBasicParsing -DisableKeepAlive -ErrorAction Stop
$gitPattern = if ($Arch.Trim().ToLower() -eq 'arm64') { 'PortableGit**ARM64*.7z.exe' } else { 'PortableGit**64*bit*.7z.exe' }
$GitAsset = $GitReleaseData.assets | Where-Object { $_.name -like $gitPattern } | Select-Object -First 1
if (-not $GitAsset) {
    Write-Host "No matching portable Git release was found for architecture '$Arch'." -ForegroundColor Red
    return
}
$GitDownloadUrl = $GitAsset.browser_download_url
$null = New-Item -Path "$RootPath\Git" -ItemType Directory -Force -ErrorAction Stop
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
if ($SkipRepo) {
    Write-Host "Repository clone was skipped by parameter."
    return
}

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    if ($Quiet) {
        Write-Host "No Git repository URL was provided. Skipping repository clone." -ForegroundColor Yellow
        return
    }

    $GitRepoUrl = Read-Host -Prompt "Enter Git Repository URL (http). Press Enter to skip"
    if ([string]::IsNullOrWhiteSpace($GitRepoUrl)) {
        Write-Host "No Git repository URL was provided. Skipping repository clone." -ForegroundColor Yellow
        return
    }
}
else {
    $GitRepoUrl = $RepoUrl
}

$GitRepoUrl = $GitRepoUrl.Trim()
$RepoName = (Split-Path -Path $GitRepoUrl.TrimEnd('/') -Leaf).Replace('.git', '')
if ([string]::IsNullOrWhiteSpace($RepoName)) {
    Write-Host "The Git repository URL is invalid. Skipping repository clone." -ForegroundColor Yellow
    return
}

$RepoDir = Join-Path -Path $RootPath -ChildPath $RepoName
if (Test-Path -Path $RepoDir) {
    Write-Host "Removing existing repository path: $RepoDir" -ForegroundColor Yellow
    Remove-Item -Path $RepoDir -Recurse -Force
}

$StartParams = @{
    'FilePath' = "$RootPath\Git\cmd\git.exe"
    'ArgumentList' = @('clone', $GitRepoUrl, $RepoDir)
    'Wait' = $true
    'WindowStyle' = 'Hidden'
}
Start-Process @StartParams
Write-Host "Git repository cloned to $RepoDir."
Write-Host "Done! You can now run the project from $RepoDir."
pause