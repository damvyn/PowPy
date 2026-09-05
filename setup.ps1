<#
.SYNOPSIS
    Sets up a local PowPy environment with Python, Git, and a project clone.

.DESCRIPTION
    Prompts for the installation directory, enables site packages,
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
    [string]$RepoUrl = ''
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
        Write-Host "`t$FilePath was downloaded." -ForegroundColor Green
        return $FilePath
    } catch { Write-Error "Failed to download file from $Url. Error: $($_.Exception.Message)" }
}


if ([string]::IsNullOrWhiteSpace($RootPath)) { $RootPath = "${env:SystemDrive}\PowPy" }
$null = New-Item -Path $RootPath -ItemType Directory -Force -ErrorAction Stop
Write-Host "Selected path: $RootPath" -foregroundcolor Yellow

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    $RepoUrl = Read-Host -Prompt "Enter Git Repository URL (http)"
    if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
        Write-Host "No Git repository URL was provided. Skipping repository clone." -ForegroundColor Yellow
        Write-Host "Add your project to ${RootPath}\Python\python314._pth" -ForegroundColor Yellow
        Write-Host "Example:"
        Write-Host "---------------"
        Write-Host "python314.zip`n.`n..{PROJECT NAME}`n`n# Uncomment to run site.main() automatically`nimport site"
        Write-Host "---------------"
    } else {
        $RepoUrl = $RepoUrl.Trim()
        $repoName = (Split-Path -Path $RepoUrl.TrimEnd('/') -Leaf).Replace('.git', '')
    }
} 


#region download Python

# get Python versions from the official Python api
$PyBaseUrl = 'https://www.python.org/api/v2/downloads/release/?is_published=true'
$PyVersUrl = $PyBaseUrl + '&is_latest=true&pre_release=false&version=3'
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
$ReleaseName = 'Windows embeddable package (64-bit)'
$DownloadUrl = ($PyDownloadData | Where-Object {
    $_.release -eq $WantedVersion.resource_uri -and $_.name -eq $ReleaseName }).url
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

$PyPth = Get-ChildItem -Path $PyDir -Filter '*._pth' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($PyPth) {
    Write-Host "Setting up Python site packages..."
    $lines = Get-Content -Path $PyPth.FullName

    for ($i = 0; $i -lt  $lines.Count; $i++) {
        if ($lines[$i].Trim -eq '#import site') {
            $lines[$i] = $lines[$i].Replace('#', '')
        }
        if ($Lines[$i].Trim() -eq '.' -and (-not [string]::IsNullOrWhiteSpace($repoName))) {
            Write-Host $repoName
            $Lines[$i] = $Lines[$i] +"`nLib\site-packages`n..\$repoName\"
        }
    }
    Set-Content -Path $PyPth.FullName -Value $Lines
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
$gitPattern = 'PortableGit**64*bit*.7z.exe'
$GitAsset = $GitReleaseData.assets | Where-Object { $_.name -like $gitPattern } | Select-Object -First 1
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
if ($repoName) {
    $RepoDir = Join-Path -Path $RootPath -ChildPath $repoName
    if (Test-Path -Path $RepoDir) {
        Write-Host "$RepoDir is already present in $RootPath. Exiting..." -ForegroundColor Yellow
        return
    }

    $StartParams = @{
        'FilePath' = "$RootPath\Git\cmd\git.exe"
        'ArgumentList' = @('clone', $RepoUrl, $RepoDir)
        'Wait' = $true
        'WindowStyle' = 'Hidden'
    }
    Write-Host "Clone $repoName"
    Start-Process @StartParams
    Write-Host "Done! You can now run the project from $RepoDir."
}
PAUSE
