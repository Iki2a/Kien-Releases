#requires -Version 5.1
param(
    [string]$InstallDirectory,
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$useGui = -not $PSBoundParameters.ContainsKey('InstallDirectory')
if ($useGui -and $NoLaunch) { throw '-NoLaunch requires -InstallDirectory.' }
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
    throw 'Kien requires 64-bit Windows 10 or later.'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repository = 'https://github.com/Iki2a/Kien-Releases'
$headers = @{ 'User-Agent' = 'Kien-Installer'; 'Accept' = 'application/vnd.github+json' }
Write-Host 'Kien - a floating notch for Windows'
Write-Host 'Checking the latest published release...'
try {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Iki2a/Kien-Releases/releases/latest' -Headers $headers -TimeoutSec 30
}
catch { throw ('No public Kien release is available, or GitHub could not be reached. See ' + $repository + '/releases') }
$asset = @($release.assets | Where-Object name -eq 'Kien-Setup.exe')
if ($asset.Count -ne 1 -or $release.draft -or $release.prerelease) { throw 'No stable Kien installer is available.' }
$asset = $asset[0]
$downloadUri = [Uri]$asset.browser_download_url
if ($downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ne 'github.com' -or
    -not $downloadUri.AbsolutePath.StartsWith('/Iki2a/Kien-Releases/releases/download/', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unexpected installer download location.'
}
if ([string]$asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw 'The release has no verified SHA-256 metadata.' }
$expectedHash = $Matches[1]
$existing = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kien' -ErrorAction SilentlyContinue
$existingPath = if ($existing) { [string]$existing.InstallLocation } else { '' }
if ($existingPath -and (Test-Path -LiteralPath (Join-Path $existingPath 'current\Kien.exe'))) {
    if ($InstallDirectory -and [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\') -ne $existingPath.TrimEnd('\')) {
        throw 'Uninstall the existing copy before selecting another installation folder.'
    }
    $InstallDirectory = $existingPath
    Write-Host ('Existing installation: ' + $InstallDirectory)
}
if (-not $useGui) {
    if ($InstallDirectory -notmatch '^[a-zA-Z]:[\\/]' -or $InstallDirectory.Contains('"') -or
        $InstallDirectory.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) { throw 'Choose an absolute folder on a local drive.' }
    $InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
    if ($InstallDirectory -eq [IO.Path]::GetPathRoot($InstallDirectory).TrimEnd('\')) { throw 'Select a folder inside the drive, such as D:\Apps\Kien.' }
    Write-Host ('Installing ' + $release.tag_name + ' to ' + $InstallDirectory)
}
else { Write-Host 'Setup will open so you can choose the installation folder using Browse.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('KienDownload-' + [Guid]::NewGuid().ToString('N'))
$setupPath = Join-Path $temporary 'Kien-Setup.exe'
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUri.AbsoluteUri -OutFile $setupPath -TimeoutSec 300
    if ((Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Installer checksum verification failed.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $setupPath
    if ($signature.Status -ne 'Valid') { throw 'The installer does not have a valid trusted signature. Installation stopped.' }
    if ($useGui) {
        $process = Start-Process -FilePath $setupPath -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw ('Kien Setup exited with code ' + $process.ExitCode + '.') }
        return
    }
    $process = Start-Process -FilePath $setupPath -ArgumentList ('--silent --installto "' + $InstallDirectory + '"') -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw ('Kien installation failed with exit code ' + $process.ExitCode + '. Check the selected folder and close Kien before retrying.') }
    $executable = Join-Path $InstallDirectory 'current\Kien.exe'
    if (-not (Test-Path -LiteralPath $executable)) { throw 'Kien was not found in the selected folder after installation.' }
    Write-Host ('Kien installed successfully: ' + $InstallDirectory)
    if (-not $NoLaunch) { Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable -Parent) -ArgumentList '--startup' }
}
finally {
    # Only remove the known downloaded file and its empty temporary folder.
    if (Test-Path -LiteralPath $setupPath) { Remove-Item -LiteralPath $setupPath }
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
